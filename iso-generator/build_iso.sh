docker build -t archer_builder .
docker create --name archer-temp-container archer_builder && docker cp archer-temp-container:/home/archer-builder/archer-*.iso ./ && docker rm archer-temp-container
