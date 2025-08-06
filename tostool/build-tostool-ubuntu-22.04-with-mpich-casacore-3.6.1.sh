eval `ssh-agent -s`
ssh-add
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 --push -t wasimraja81/askappy-ubuntu-22.04:tostool-2.28.0 -f Dockerfile-tostool-ubuntu-22.04-with-mpich-casacore-3.6.1.txt --build-arg SSH_KEY_PRI="$(more ~/.ssh/id_rsa)" --build-arg SSH_KEY_PUB="$(more ~/.ssh/id_rsa.pub)" --build-arg SSH_KNOWNHOSTS="$(more ~/.ssh/known_hosts)" .
