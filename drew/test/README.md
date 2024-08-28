How to prepare testing:
`git submodule update --init --recursive`

How to start tests:
cd to `drew` folder,
start the command `.docker run --rm -it -v ${PWD}:/code armdocker.rnd.ericsson.se/proj-am/jenkins/bats:1.10.0-1 /code//test/drew.bats`