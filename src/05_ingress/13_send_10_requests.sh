#!/bin/bash
SERVER_NAME=hello-world.example

for i in {1..10}
do
  echo "Petición $i:"
  curl "$SERVER_NAME"
  echo ""   # línea en blanco para separar
done

