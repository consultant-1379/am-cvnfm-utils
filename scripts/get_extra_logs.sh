log_base_dir=extra_logs_${namespace}_$(date "+%Y-%m-%d-%H-%M-%S")
log_base_path=$PWD/${log_base_dir}
mkdir ${log_base_dir}

get_ingress_logs() {
    #echo "---------------------------------------"
    echo "-Getting logs per Ingress POD-"
    #echo "---------------------------------------"
    #echo "---------------------------------------"

    ingress_dir=${log_base_path}/ingress
    ingress_namespace=ingress-nginx
    mkdir ${ingress_dir}
    kubectl --namespace ${ingress_namespace} get pods > ${ingress_dir}/kube_ingress_podstolog.txt

    for i in `kubectl --namespace ${ingress_namespace} get pods | grep -v NAME | awk '{print $1}'`
        do
            for j in `kubectl --namespace ${ingress_namespace} get pod $i -o jsonpath='{.spec.containers[*].name}'`
                do
                    kubectl --namespace ${ingress_namespace} logs --since 70m $i -c $j > ${log_base_dir}/${i}_${j}.txt
                done
        done
}

compress_files() {
    echo "Generating tar file and removing extra_logs directory..."
    tar cvfz $PWD/${log_base_dir}.tgz ${log_base_dir}
    echo  -e "\e[1m\e[31mGenerated file $PWD/${log_base_dir}.tgz\e[0m"
    rm -r $PWD/${log_base_dir}
}

get_ingress_logs
compress_files