#!/bin/bash

set -e

# Verificar que estamos dentro de un repositorio Git
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Error: esta carpeta no es un repositorio Git."
    exit 1
fi

# Verificar si existen cambios
if git diff --quiet && git diff --cached --quiet && \
   [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "No hay cambios para subir."
    exit 0
fi

# Usar el mensaje recibido o uno predeterminado
MENSAJE="${1:-Actualización del QA Playbook}"

echo "Agregando cambios..."
git add .

echo "Creando commit..."
git commit -m "$MENSAJE"

echo "Actualizando desde GitHub..."
git pull --rebase origin main

echo "Subiendo cambios..."
git push origin main

echo "Proceso terminado correctamente."