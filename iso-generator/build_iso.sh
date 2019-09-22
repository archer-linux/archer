docker build --no-cache -t archer_builder .
docker create --name archer-temp-container archer_builder && docker cp archer-temp-container:/home/archer-builder/archer/build/ ./

docker rm archer-temp-container
docker rmi archer_builder

echo "Done building Archer"
ls -lah ./build/archer-*
