#eval `ssh-agent -s`
#ssh-add
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 --push -t wasimraja81/askappy-ubuntu-24.04:base-mpich-casacore-3.6.1 -f Dockerfile .
