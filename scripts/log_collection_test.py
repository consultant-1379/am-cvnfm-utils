import os
import logging
import sys
import timeit
import json
from datetime import date, datetime, timedelta
from json import JSONDecodeError
from threading import Thread
from typing import Tuple

import requests
import urllib3
from requests import Response, PreparedRequest
from requests.exceptions import (MissingSchema, InvalidURL)

PWD = os.getcwd()
BASE_PATH = f'endurance-log-reports'
LOG_REPORT_PATH = f'/{PWD}/{BASE_PATH}/cron_{date.today()}'
ERROR_LOG_REPORT_PATH = f'/{PWD}/{BASE_PATH}/errors/cron_{date.today()}'
LOG_API_PATH = "/log/viewer/api/v2/sources/query"
LOG = logging.getLogger(__name__)
TIME_PATTERN = '%H:%M:%S'
LOG_FILE_TIMESTAMP = f'{datetime.now().strftime(TIME_PATTERN)}'
REPORT_FILE = f'{LOG_REPORT_PATH}/log_collection_{LOG_FILE_TIMESTAMP}.log'
ERRORS_FILE = f'{ERROR_LOG_REPORT_PATH}/errors_log_collection_{LOG_FILE_TIMESTAMP}.log'


def script_banner() -> None:
    """ Print a small banner for the script """
    message = f'###################################################################################################\n' \
              f'#######################  RUNNING LOG COLLECTION PERFORMANCE TEST FROM CRON  #######################\n' \
              f'###################################################################################################\n'
    with open(REPORT_FILE, "w") as report_file:
        report_file.write(message)


def usage() -> str:
    """ Print the usage for the script """
    LOG.info('Usage: python3 log_collection_test.py <host> <user_name> <user_password>')
    return ('Example: python3 log_collection_test.py https://vnfm.ccd-c3b002-iccr.athtem.eei.ericsson.se '
            'vnfm Ericsson123!')


def is_input_valid() -> bool:
    """ Check that the correct number of inputs are provided """
    is_valid = True
    if 4 < len(sys.argv) or len(sys.argv) < 4:
        raise ArithmeticError('Error: Not valid amount of inputs provided! ' + usage())
    host = sys.argv[1]
    try:
        PreparedRequest().prepare_url(host, params=None)
    except (MissingSchema, InvalidURL, UnicodeError):
        raise InvalidURL(f'Error: Invalid host provided: {host}')
    return is_valid


def get_headers(jsession_id: str) -> dict:
    """ Method to get headers for EVNFM requests """
    return {'Accept': "application/json", 'Content-Type': "application/json",
            'cookie': f'JSESSIONID={jsession_id}'}


def get_log_collection_time_range() -> Tuple[str, str]:
    """
    Method to get date-time start and date-time end for the log collection request body
    :return the current date time and the date time of 24 hours ago in the format YYYY-MM-DDTHH:MM:SS.sssZ
    :rtype : tuple of strings
    """
    time_now = datetime.utcnow()
    twenty_four_hours_ago = (time_now - timedelta(days=1)).isoformat(sep='T', timespec='milliseconds')
    return twenty_four_hours_ago, time_now.isoformat(sep='T', timespec='milliseconds')


def get_body(query: str, num_entries: int) -> str:
    """
    Method to get the body of the log collection request
    :param log_collection_time_range : logs time range
    :type: tuple
    :param query : query for filtering log records
    :type: str
    :param num_entries : number of log records to get
    :type: int
    :return body of the log collection request
    :rtype password: str
    """
    log_collection_time_range = get_log_collection_time_range()
    LOG.info(f'Logs range : 1 day, from {log_collection_time_range[0]} ---> {log_collection_time_range[1]}')
    body = {
        "source": {
            "method": "array",
            "sources": [
                {
                    "query": f'{query}',
                    "sortOrder": "desc",
                    "sourceFields": {
                        "message": "message",
                        "service_id": "service_id",
                        "severity": "severity",
                        "timestamp": "timestamp"
                    },
                    "sourceType": "elasticRequestBodySearch",
                    "target": "adp-app-audit-logs*,eo*",
                    "timeFilterField": "timestamp"
                }
            ],
            "sourceType": "aggregation"
        },
        "options": {
            "timeRange": {
                "start": f'{log_collection_time_range[0]}',
                "end": f'{log_collection_time_range[1]}'
            },
            "pagination": {
                "currentPage": 1,
                "numEntries": num_entries,
                "sortMode": "desc",
                "sortAttr": "timestamp",
                "filter": "",
                "filterLabel": ""
            }
        }
    }
    return json.dumps(body)


def login(host: str, user: str, password: str) -> str:
    """
    Method to get a jsession id using set user and password
    :return: jsession id or None if an incorrect status code is received
    :rtype: str
    """
    response = requests.post(f'{host}/auth/v1',
                             headers={'X-login': user,
                                      'X-password': password,
                                      'Content-Type': "application/json"}, verify=False)
    if response.status_code != 200:
        raise AssertionError(f'Error: User cannot login. Received {response.status_code} status code. '
                             f'Invalid credentials were provided.')
    return response.text


def get_logs(host: str, jsession_id: str) -> Response:
    """
    Method to run the request to get the logs
    :param host: hostname
    :type host: str
    :param jsession_id: user jsession id
    :type jsession_id: str
    :return response: log collection response or None if invalid response status code received
    :rtype: requests.Response
    """
    response = requests.post(f'{host}{LOG_API_PATH}',
                             headers=get_headers(jsession_id),
                             verify=False,
                             data=get_body('(*)', 2000))

    if response.status_code != 200:
        if response.status_code == 422:
            raise AssertionError(f'Error: Received {response.status_code} status code. Please check the request. '
                                 f'Possible issue "rangeInfo" field on line 109 should be "timeRange" or vice versa.')
        else:
            raise AssertionError(f'Error: Received status code {response.status_code} while retrieving the logs')
    try:
        json.loads(get_body('(*)', 2000))
    except (JSONDecodeError, TypeError) as errors:
        raise TypeError(f'Error: Invalid json body for the log collection request. Error: {errors}')
    try:
        number_of_logs = len(json.loads(response.text)[0]["pageData"])
        if number_of_logs != 2000:
            raise AssertionError(f'Error: Received incorrect number of logs: {number_of_logs}')
    except (JSONDecodeError, TypeError) as errors:
        raise TypeError(f'Error: Invalid json body for the log collection response. Error: {errors}')
    return response


def verify_response_time(response_time: float) -> None:
    """
    Method to execute the test
    :param response_time: response time in seconds
    :type response_time: float
    """
    maximum_response_time = 30.0
    if response_time > maximum_response_time:
        raise AssertionError(f'Error: Received response in {response_time} seconds, which is more than the '
                             f'expected maximum time of {maximum_response_time} seconds')
    else:
        LOG.info(f'Response time : {response_time} seconds')


def test_logs(host: str, user: str, password: str) -> None:
    """
    Method to execute the test
    :param host: hostname
    :type host: str
    :param user: username
    :type user: str
    :param password: user password
    :type password: str
    """
    jsession_id = login(host, user, password)
    if jsession_id is not None:
        LOG.info(f'JSESSION ID : {jsession_id}')
        response = get_logs(host, jsession_id)
        if response is not None:
            verify_response_time(response.elapsed.total_seconds())
        try:
            response_errors = get_orchestrator_errors_logs(host, jsession_id)
            errors = json.loads(response_errors.text)[0]["pageData"]
            errors_logs_count = len(errors)
            if errors_logs_count != 0:
                try:
                    if not os.path.exists(ERROR_LOG_REPORT_PATH):
                        os.makedirs(ERROR_LOG_REPORT_PATH)
                    with open(ERRORS_FILE, "w") as errors_file:
                        LOG.info(f'File with error logs is created: {ERRORS_FILE}')
                        errors_file.writelines([f'Test failed: {errors_logs_count} errors found in logs\n',
                                               json.dumps(errors, indent=4)])
                except OSError as error:
                    raise OSError(f'Error: OS error occurred trying to open {ERRORS_FILE} file due to {error}')
        except (JSONDecodeError, TypeError) as error:
            raise TypeError(f'Error: Invalid json in the response. Error: {error}')


def get_orchestrator_errors_logs(host: str, jsession_id: str) -> Response:
    """
    Method to get errors logs for the orchestrator service
    :param host: hostname
    :type host: str
    :param jsession_id: user jsession id
    :type jsession_id: str
    :return response: orchestrator errors log collection response or None if invalid response status code received
    :rtype: requests.Response
    """
    response = requests.post(f'{host}{LOG_API_PATH}',
                             headers=get_headers(jsession_id),
                             verify=False,
                             data=get_body('(service_id: \"orchestrator\") AND severity:Error', 2000))
    if response.status_code != 200:
        if response.status_code == 422:
            raise AssertionError(f'Error: Received {response.status_code} status code. Please check the request. '
                                 f'Possible issue - "rangeInfo" field should be "timeRange" or vice versa.')
        else:
            raise AssertionError(f'Error: Received status code {response.status_code} while retrieving the logs')
    return response


def configure_logger() -> None:
    """
    Method to configure logging. In this method directory for reports is created.
    Logger is configured with default report name, log format and log level.
    """
    if not os.path.exists(LOG_REPORT_PATH):
        os.makedirs(LOG_REPORT_PATH)
    logging.basicConfig(filename=REPORT_FILE, filemode="a",
                        level=logging.INFO, format="[%(asctime)s] [%(levelname)s]: %(message)s")


if __name__ == '__main__':
    configure_logger()
    script_banner()
    if is_input_valid():
        host = sys.argv[1]
        user = sys.argv[2]
        password = sys.argv[3]
        thread_collection = []
        urllib3.disable_warnings()
        start = timeit.default_timer()
        LOG.info('Executing logs collection test')
        LOG.info('Executing test for getting errors logs from the Orchestrator service')
        try:
            for i in range(0, 7):
                thread = Thread(target=test_logs, args=(host, user, password))
                thread.start()
                thread_collection.append(thread)
            for thread in thread_collection:
                thread.join()
        except Exception as error:
            LOG.error(f'Error occurred: {error}')
        end = timeit.default_timer()
        LOG.info(f'Total execution time for all {len(thread_collection)} users is {end - start} seconds')
