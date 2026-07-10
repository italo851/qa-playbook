#!/bin/bash

set -e

# Verificar repositorio
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "No estás dentro de un repositorio Git."
    exit 1
fi

# Obtener archivos modificados
mapfile -t archivos < <(git status --porcelain | awk '{print $2}')

if [ ${#archivos[@]} -eq 0 ]; then
    echo "No hay archivos modificados."
    exit 0
fi

echo ""
echo "Archivos modificados:"
echo "----------------------"

for i in "${!archivos[@]}"; do
    echo "$((i+1)). ${archivos[$i]}"
done

echo ""
read -p "Elegí el número del archivo: " opcion

archivo=${archivos[$((opcion-1))]}

if [ -z "$archivo" ]; then
    echo "Opción inválida."
    exit 1
fi

echo ""
echo "Seleccionaste: $archivo"

read -p "Mensaje del commit: " mensaje

git add "$archivo"
git commit -m "$mensaje"
git pull --rebase origin main
git push origin main

echo ""
<<<<<<< HEAD
echo "✅ Archivo publicado correctamente."
=======
echo "✅ Archivo publicado correctamente."
>>>>>>> 2230dd4 (modificacion para aprender)
