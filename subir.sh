#!/usr/bin/env bash

set -Eeuo pipefail

RUTA_REPOSITORIO="/c/Proyectos/Github/qa-playbook"
REMOTO="origin"

mostrar_error() {
    echo ""
    echo "❌ Error: $1"
    echo ""
    read -r -p "Presioná Enter para cerrar..."
    exit 1
}

pausar() {
    echo ""
    read -r -p "Presioná Enter para cerrar..."
}

cancelar_operacion() {
    echo ""
    echo "Operación cancelada."
    pausar
    exit 0
}

clear

echo "=================================================="
echo "           PUBLICAR ARCHIVO EN GITHUB"
echo "=================================================="
echo ""

command -v git >/dev/null 2>&1 ||
    mostrar_error "Git no está instalado o no está disponible en Git Bash."

[ -d "$RUTA_REPOSITORIO" ] ||
    mostrar_error "No se encontró la carpeta: $RUTA_REPOSITORIO"

cd "$RUTA_REPOSITORIO" ||
    mostrar_error "No se pudo entrar al repositorio."

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    mostrar_error "La carpeta no es un repositorio Git."

git remote get-url "$REMOTO" >/dev/null 2>&1 ||
    mostrar_error "No existe el remoto '$REMOTO'."

URL_REMOTO="$(git remote get-url "$REMOTO")"
DIRECTORIO_GIT="$(git rev-parse --git-dir)"
RAMA_ACTUAL="$(git branch --show-current)"

[ -n "$RAMA_ACTUAL" ] ||
    mostrar_error "Git está en estado detached HEAD. Cambiá primero a una rama."

if [ -d "$DIRECTORIO_GIT/rebase-merge" ] ||
   [ -d "$DIRECTORIO_GIT/rebase-apply" ]; then
    mostrar_error "Hay un rebase pendiente. Ejecutá 'git rebase --continue' o 'git rebase --abort'."
fi

if [ -f "$DIRECTORIO_GIT/MERGE_HEAD" ]; then
    mostrar_error "Hay un merge pendiente. Resolvé los conflictos antes de continuar."
fi

if [ -f "$DIRECTORIO_GIT/CHERRY_PICK_HEAD" ]; then
    mostrar_error "Hay un cherry-pick pendiente. Ejecutá 'git cherry-pick --continue' o 'git cherry-pick --abort'."
fi

echo "✅ Repositorio detectado."
echo "✅ Rama actual: $RAMA_ACTUAL"
echo "✅ Remoto: $URL_REMOTO"
echo ""

echo "Consultando el repositorio remoto..."

git fetch "$REMOTO" ||
    mostrar_error "No se pudo conectar con el repositorio remoto."

echo "✅ Información remota actualizada."
echo ""

RAMA_REMOTA="$REMOTO/$RAMA_ACTUAL"

if git show-ref --verify --quiet "refs/remotes/$RAMA_REMOTA"; then
    COMMITS_ADELANTE="$(git rev-list --count "$RAMA_REMOTA..HEAD")"
    COMMITS_DETRAS="$(git rev-list --count "HEAD..$RAMA_REMOTA")"

    if [ "$COMMITS_ADELANTE" -gt 0 ] && [ "$COMMITS_DETRAS" -gt 0 ]; then
        mostrar_error "La rama está divergida: tenés $COMMITS_ADELANTE commit(s) locales y $COMMITS_DETRAS remoto(s). No se hará un pull automático."
    fi

    if [ "$COMMITS_DETRAS" -gt 0 ]; then
        mostrar_error "La rama local está $COMMITS_DETRAS commit(s) detrás de '$RAMA_REMOTA'. Actualizala manualmente antes de publicar."
    fi

    if [ "$COMMITS_ADELANTE" -gt 0 ]; then
        echo "ℹ️  La rama tiene $COMMITS_ADELANTE commit(s) locales pendientes de subir."
        echo ""
    else
        echo "✅ La rama local está sincronizada con '$RAMA_REMOTA'."
        echo ""
    fi
else
    echo "⚠️  La rama remota '$RAMA_REMOTA' todavía no existe."
    echo "Se creará durante el primer push."
    echo ""
fi

ARCHIVOS=()
ESTADOS=()

while IFS= read -r -d '' entrada; do
    estado="${entrada:0:2}"
    archivo="${entrada:3}"

    if [[ "$estado" == *R* || "$estado" == *C* ]]; then
        IFS= read -r -d '' ruta_anterior || true
    fi

    ARCHIVOS+=("$archivo")
    ESTADOS+=("$estado")
done < <(git status --porcelain=v1 -z)

if [ "${#ARCHIVOS[@]}" -eq 0 ]; then
    echo "No hay archivos modificados, nuevos o eliminados."
    pausar
    exit 0
fi

echo "Archivos con cambios:"
echo "--------------------------------------------------"

for i in "${!ARCHIVOS[@]}"; do
    numero=$((i + 1))
    estado="${ESTADOS[$i]}"
    archivo="${ARCHIVOS[$i]}"

    case "$estado" in
        "??") descripcion="Nuevo" ;;
        *R*)  descripcion="Renombrado" ;;
        *C*)  descripcion="Copiado" ;;
        *D*)  descripcion="Eliminado" ;;
        *A*)  descripcion="Agregado" ;;
        *M*)  descripcion="Modificado" ;;
        *)    descripcion="Con cambios" ;;
    esac

    printf "%d. [%s] %s\n" "$numero" "$descripcion" "$archivo"
done

echo ""
echo "0. Cancelar"
echo ""

while true; do
    read -r -p "Elegí el número del archivo: " OPCION

    if ! [[ "$OPCION" =~ ^[0-9]+$ ]]; then
        echo "⚠️  Debés ingresar solamente un número."
        continue
    fi

    if [ "$OPCION" -eq 0 ]; then
        cancelar_operacion
    fi

    if [ "$OPCION" -ge 1 ] &&
       [ "$OPCION" -le "${#ARCHIVOS[@]}" ]; then
        break
    fi

    echo "⚠️  La opción seleccionada no existe."
done

INDICE=$((OPCION - 1))
ARCHIVO_SELECCIONADO="${ARCHIVOS[$INDICE]}"
ESTADO_SELECCIONADO="${ESTADOS[$INDICE]}"

echo ""
echo "Archivo seleccionado:"
echo "$ARCHIVO_SELECCIONADO"
echo ""

echo "Vista previa de los cambios:"
echo "--------------------------------------------------"

if [[ "$ESTADO_SELECCIONADO" == "??" ]]; then
    echo "El archivo es nuevo y todavía no está registrado por Git."
elif [[ "$ESTADO_SELECCIONADO" == *D* ]]; then
    echo "El archivo fue eliminado."
else
    git --no-pager diff -- "$ARCHIVO_SELECCIONADO" || true
    git --no-pager diff --cached -- "$ARCHIVO_SELECCIONADO" || true
fi

echo "--------------------------------------------------"
echo ""

read -r -p "¿Querés publicar este archivo? (s/n): " CONFIRMACION

case "${CONFIRMACION,,}" in
    s|si|sí) ;;
    *) cancelar_operacion ;;
esac

while true; do
    echo ""
    read -r -p "Ingresá el mensaje del commit: " MENSAJE

    MENSAJE_SIN_ESPACIOS="${MENSAJE//[[:space:]]/}"

    if [ -n "$MENSAJE_SIN_ESPACIOS" ]; then
        break
    fi

    echo "⚠️  El mensaje del commit no puede estar vacío."
done

echo ""
echo "Agregando el archivo seleccionado..."

git add -- "$ARCHIVO_SELECCIONADO" ||
    mostrar_error "No se pudo agregar el archivo."

if git diff --cached --quiet -- "$ARCHIVO_SELECCIONADO"; then
    mostrar_error "El archivo seleccionado no tiene cambios para guardar."
fi

echo "✅ Archivo agregado al área de preparación."
echo ""

echo "Resumen del archivo preparado:"
echo "--------------------------------------------------"
git --no-pager diff --cached --stat -- "$ARCHIVO_SELECCIONADO"
echo "--------------------------------------------------"
echo ""

echo "Creando commit..."

git commit -m "$MENSAJE" -- "$ARCHIVO_SELECCIONADO" ||
    mostrar_error "No se pudo crear el commit."

echo ""
echo "✅ Commit creado correctamente."
echo ""

echo "Publicando la rama '$RAMA_ACTUAL'..."

if git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1; then
    git push ||
        mostrar_error "No se pudo publicar el commit."
else
    git push --set-upstream "$REMOTO" "$RAMA_ACTUAL" ||
        mostrar_error "No se pudo crear/publicar la rama remota."
fi

echo ""
echo "=================================================="
echo "       ✅ ARCHIVO PUBLICADO CORRECTAMENTE"
echo "=================================================="
echo ""
echo "Repositorio: $RUTA_REPOSITORIO"
echo "Remoto:      $URL_REMOTO"
echo "Rama:        $RAMA_ACTUAL"
echo "Archivo:     $ARCHIVO_SELECCIONADO"
echo "Mensaje:     $MENSAJE"
echo ""
echo "Último commit:"
git --no-pager log -1 --oneline
echo ""

pausar
