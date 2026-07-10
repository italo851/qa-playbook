#!/bin/bash

set -e

# Verificar que estamos en un repositorio Git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "❌ No estás dentro de un repositorio Git."
    exit 1
fi

# Verificar cambios
if [ -z "$(git status --porcelain)" ]; then
    echo "✅ No hay cambios para subir."
    exit 0
fi

MENSAJE="${1:-Actualización del QA Playbook}"

echo "📄 Agregando archivos..."
git add .

echo "💾 Creando commit..."
git commit -m "$MENSAJE"

echo "⬇️ Actualizando repositorio..."
git pull --rebase origin main

echo "⬆️ Subiendo cambios..."
git push origin main

echo "🎉 ¡Todo salió correctamente!"