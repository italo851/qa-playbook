#!/bin/bash

set -euo pipefail

RUTA_REPOSITORIO="/c/Proyectos/Github/qa-playbook"
REMOTO="origin"
RAMA="main"

error() {
    echo ""
    echo "❌ Error: $1"
    read -r -p "Presioná Enter para cerrar..."
    exit 1
}

pausar() {
    echo ""
    read -r -p "Presioná Enter para cerrar..."
}

cancelar() {
    echo ""
    echo "Operación cancelada."
    pausar
    exit 0
}

clear

echo "=================================================="
echo "           PUBLICAR ARCHIVO CON GIT"
echo "=================================================="
echo ""

command -v git >/dev/null 2>&1 || error "Git no está instalado."
[ -d "$RUTA_REPOSITORIO" ] || error "No existe la carpeta: $RUTA_REPOSITORIO"

cd "$RUTA_REPOSITORIO" || error "No se pudo ingresar al repositorio."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || error "La carpeta no es un repositorio Git."
git remote get-url "$REMOTO" >/dev/null 2>&1 || error "No existe el remoto '$REMOTO'."

URL_REMOTO=$(git remote get-url "$REMOTO")
RAMA_ACTUAL=$(git branch --show-current)

[ -n "$RAMA_ACTUAL" ] || error "Git está en estado detached HEAD."

if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
    error "Hay un rebase pendiente."
fi

[ ! -f ".git/MERGE_HEAD" ] || error "Hay un merge pendiente."

git show-ref --verify --quiet "refs/heads/$RAMA" || error "No existe la rama '$RAMA'."

if [ "$RAMA_ACTUAL" != "$RAMA" ]; then
    echo "Cambiando de '$RAMA_ACTUAL' a '$RAMA'..."
    git switch "$RAMA" || error "No se pudo cambiar a '$RAMA'."
fi

echo "Repositorio: $RUTA_REPOSITORIO"
echo "Rama:        $RAMA"
echo "Remoto:      $URL_REMOTO"
echo ""

ARCHIVOS=()
ESTADOS=()

while IFS= read -r linea; do
    estado="${linea:0:2}"
    archivo="${linea:3}"
    [[ "$archivo" == *" -> "* ]] && archivo="${archivo##* -> }"
    ARCHIVOS+=("$archivo")
    ESTADOS+=("$estado")
done < <(git status --porcelain)

[ "${#ARCHIVOS[@]}" -gt 0 ] || { echo "No hay cambios para publicar."; pausar; exit 0; }

echo "Archivos con cambios:"
echo "--------------------------------------------------"

for i in "${!ARCHIVOS[@]}"; do
    case "${ESTADOS[$i]}" in
        "??") descripcion="Nuevo" ;;
        *M*) descripcion="Modificado" ;;
        *D*) descripcion="Eliminado" ;;
        *R*) descripcion="Renombrado" ;;
        *A*) descripcion="Agregado" ;;
        *) descripcion="Con cambios" ;;
    esac
    printf "%d. [%s] %s\n" "$((i+1))" "$descripcion" "${ARCHIVOS[$i]}"
done

echo "0. Cancelar"
echo ""

read -r -p "Elegí el número del archivo: " OPCION
[[ "$OPCION" =~ ^[0-9]+$ ]] || error "Ingresá solamente un número."
[ "$OPCION" -eq 0 ] && cancelar
[ "$OPCION" -ge 1 ] && [ "$OPCION" -le "${#ARCHIVOS[@]}" ] || error "Opción inválida."

INDICE=$((OPCION-1))
ARCHIVO="${ARCHIVOS[$INDICE]}"
ESTADO="${ESTADOS[$INDICE]}"

echo ""
echo "Archivo seleccionado: $ARCHIVO"
echo ""

if [[ "$ESTADO" != "??" && "$ESTADO" != *D* ]]; then
    git --no-pager diff -- "$ARCHIVO" || true
    git --no-pager diff --cached -- "$ARCHIVO" || true
fi

echo ""
read -r -p "¿Querés publicar este archivo? (s/n): " RESPUESTA
case "$RESPUESTA" in
    s|S|si|SI|Si|sí|Sí) ;;
    *) cancelar ;;
esac

read -r -p "Mensaje del commit: " MENSAJE
[[ -n "${MENSAJE//[[:space:]]/}" ]] || error "El mensaje no puede estar vacío."

git fetch "$REMOTO" || error "No se pudo conectar al remoto."

if git show-ref --verify --quiet "refs/remotes/$REMOTO/$RAMA"; then
    COMMITS=$(git rev-list --count "HEAD..$REMOTO/$RAMA")
    if [ "$COMMITS" -gt 0 ]; then
        git pull --rebase --autostash "$REMOTO" "$RAMA" || error "Falló el pull."
    fi
fi

git add -- "$ARCHIVO" || error "No se pudo agregar el archivo."
git diff --cached --quiet -- "$ARCHIVO" && error "No hay cambios para guardar."

git commit -m "$MENSAJE" -- "$ARCHIVO" || error "No se pudo crear el commit."
git push "$REMOTO" "$RAMA" || error "No se pudo realizar el push."

echo ""
echo "✅ Publicación completada."
git --no-pager log -1 --oneline

pausar