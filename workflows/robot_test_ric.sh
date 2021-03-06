#!/bin/bash
#-----------Pre-modification------------------------------
cd RIC
git clone https://gerrit.o-ran-sc.org/r/it/test
cp test/ric_robot_suite/helm/robot_install.sh /home/cloudadmin/RIC/dep/generated/ricplt

#-----------Changing the repo location to rec.io-----------
sed -i 's,snapshot.docker.ranco-dev-tools.eastus.cloudapp.azure.com:10001,registry.kube-system.svc.rec.io:5555,g' test/ric_robot_suite/helm/ric-robot/values.yaml
sed -ri '/nodePort: 30209/d' test/ric_robot_suite/helm/ric-robot/values.yaml
sed -ri 's/^(\s*)(type\s*:\s*NodePort\s*$)/\1type: ClusterIP/' test/ric_robot_suite/helm/ric-robot/values.yaml
sed -i 's/  tag: latest/  tag: 0.1.0-SNAPSHOT-20190318152929/' test/ric_robot_suite/helm/ric-robot/values.yaml
cd dep/generated/ricplt

#-----------Doing the Docker pull--------------------------
#echo "docker" | docker login -u docker --password-stdin snapshot.docker.ranco-dev-tools.eastus.cloudapp.azure.com:10001
#docker pull snapshot.docker.ranco-dev-tools.eastus.cloudapp.azure.com:10001/test/ric-robot:latest
docker pull rancodev/ric-robot:0.1.0-SNAPSHOT-20190318152929
#docker logout snapshot.docker.ranco-dev-tools.eastus.cloudapp.azure.com:10001


#-----------Retagging---------------------------------------
docker tag  rancodev/ric-robot:0.1.0-SNAPSHOT-20190318152929 registry.kube-system.svc.rec.io:5555/test/ric-robot:0.1.0-SNAPSHOT-20190318152929
docker push  registry.kube-system.svc.rec.io:5555/test/ric-robot:0.1.0-SNAPSHOT-20190318152929


#----------- robot_install----------------------------------
#  Note:
#  This file needs to be in the it/dep/generated/ricplt directory with ric_install.sh/ric_uninstall.sh
#  so that it can use the same dist/packages as the ricplt install
#
#  ricplt is in:     it/dep/geneated/ricplt
#  ric-robot is in:  it/test/ric_robot_suite
#
if [ ! -e ric-robot ]; then
    ln  -s ../../../test/ric_robot_suite/helm/ric-robot  ric-robot
fi


helm repo add localric http://127.0.0.1:8879/charts
helm package -d dist/packages ric-robot
pkill helm
helm serve --repo-path dist/packages &
sleep 2
helm repo update

# if you need to override the repo change the image.repository line for deployment
# helm install local/ric-robot --namespace ricplatform --name ric-robot --set image.repository=snapshot.docker.ranco-dev-tools.eastus.cloudapp.azure.com:10001/test/ric-robot
#
helm install localric/ric-robot --namespace ricplatform --name ric-robot
helm repo update
#cd ../../../
ric_robot_pod=$(kubectl get pods -l app.kubernetes.io/instance=ric-robot -n ricplatform -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}')
kubectl exec -n ricplatform -it $ric_robot_pod -- sed -i '17,19 s/^/#/' /var/opt/RIC/robot/testsuites/health-check.robot

#---------show the test cases------------------------------
cd /home/cloudadmin/RIC/test/ric_robot_suite/helm/ric-robot/
bash ete-k8s.sh ricplatform health
#--------------kill helm---------------------------------------------------------------------
pkill helm
#----------checking the status of the pods------------------
sleep 30
command="$(kubectl get po --no-headers --namespace=ricplatform --field-selector status.phase!=Running 2> /dev/null)"
if [[ $command != "" ]]; then
  exit 1
fi

