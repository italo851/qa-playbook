#!/bin/bash

set -euo pipefail

# ==========================================================
# CONFIGURACIÓN
# ==========================================================

RUTA_REPOSITORIO="/c/Proyectos/Github/qa-playbook"
REMOTO="origin"
RAMA="main"

# ==========================================================
# FUNCIONES
# ==========================================================

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

# ==========================================================
# INICIO
# ==========================================================

clear

echo "=================================================="
echo "           PUBLICAR ARCHIVO EN GITHUB"
echo "=================================================="
echo ""

# Verificar que Git esté instalado
if ! command -v git >/dev/null 2>&1; then
    mostrar_error "Git no está instalado o no está disponible en Git Bash."
fi

# Verificar que exista la carpeta
if [ ! -d "$RUTA_REPOSITORIO" ]; then
    mostrar_error "No se encontró la carpeta: $RUTA_REPOSITORIO"
fi

# Entrar al repositorio
cd "$RUTA_REPOSITORIO" || mostrar_error "No se pudo entrar al repositorio."

echo "Repositorio:"
echo "$RUTA_REPOSITORIO"
echo ""

# Verificar que sea un repositorio Git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mostrar_error "La carpeta no es un repositorio Git."
fi

# Verificar que exista el remoto
if ! git remote get-url "$REMOTO" >/dev/null 2>&1; then
    mostrar_error "No existe el remoto '$REMOTO'."
fi

URL_REMOTO=$(git remote get-url "$REMOTO")

# Verificar que no haya un merge o rebase pendiente
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
    mostrar_error "Hay un rebase pendiente. Ejecutá 'git rebase --continue' o 'git rebase --abort'."
fi

if [ -f ".git/MERGE_HEAD" ]; then
    mostrar_error "Hay un merge pendiente. Resolvé los conflictos antes de continuar."
fi

# Obtener rama actual
RAMA_ACTUAL=$(git branch --show-current)

# Verificar que la rama main exista localmente
if ! git show-ref --verify --quiet "refs/heads/$RAMA"; then
    mostrar_error "No existe la rama local '$RAMA'."
fi

# Cambiar a main si se está en otra rama
if [ "$RAMA_ACTUAL" != "$RAMA" ]; then
    echo "Actualmente estás en la rama: $RAMA_ACTUAL"
    echo "Cambiando a la rama: $RAMA"
    echo ""

    git switch "$RAMA" || mostrar_error "No se pudo cambiar a la rama '$RAMA'."
fi

echo "✅ Repositorio detectado."
echo "✅ Rama: $RAMA"
echo "✅ Remoto: $URL_REMOTO"
echo ""

# ==========================================================
# OBTENER ARCHIVOS CON CAMBIOS
# ==========================================================

ARCHIVOS=()
ESTADOS=()

while IFS= read -r linea; do
    estado="${linea:0:2}"
    archivo="${linea:3}"

    # En archivos renombrados puede aparecer:
    # archivo_viejo -> archivo_nuevo
    if [[ "$archivo" == *" -> "* ]]; then
        archivo="${archivo##* -> }"
    fi

    ARCHIVOS+=("$archivo")
    ESTADOS+=("$estado")
done < <(git status --porcelain)

# Verificar si existen cambios
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
        "??")
            descripcion="Nuevo"
            ;;
        *M*)
            descripcion="Modificado"
            ;;
        *D*)
            descripcion="Eliminado"
            ;;
        *R*)
            descripcion="Renombrado"
            ;;
        *A*)
            descripcion="Agregado"
            ;;
        *C*)
            descripcion="Copiado"
            ;;
        *)
            descripcion="Con cambios"
            ;;
    esac

    printf "%d. [%s] %s\n" "$numero" "$descripcion" "$archivo"
done

echo ""
echo "0. Cancelar"
echo ""

# ==========================================================
# SELECCIONAR ARCHIVO
# ==========================================================

read -r -p "Elegí el número del archivo: " OPCION

# Validar que sea un número
if ! [[ "$OPCION" =~ ^[0-9]+$ ]]; then
    mostrar_error "Debés ingresar solamente un número."
fi

# Cancelar
if [ "$OPCION" -eq 0 ]; then
    cancelar_operacion
fi

# Validar rango
if [ "$OPCION" -lt 1 ] || [ "$OPCION" -gt "${#ARCHIVOS[@]}" ]; then
    mostrar_error "La opción seleccionada no existe."
fi

INDICE=$((OPCION - 1))
ARCHIVO_SELECCIONADO="${ARCHIVOS[$INDICE]}"
ESTADO_SELECCIONADO="${ESTADOS[$INDICE]}"

echo ""
<<<<<<< HEAD
<<<<<<< HEAD
echo "✅ Archivo publicado correctamente."
=======
echo "✅ Archivo publicado correctamente."
>>>>>>> 2230dd4 (modificacion para aprender)
=======
echo "Archivo seleccionado:"
echo "$ARCHIVO_SELECCIONADO"
echo ""

# ==========================================================
# MOSTRAR CAMBIOS
# ==========================================================

echo "Vista previa de los cambios:"
echo "--------------------------------------------------"

if [[ "$ESTADO_SELECCIONADO" == "??" ]]; then
    echo "El archivo es nuevo y todavía no está registrado por Git."

elif [[ "$ESTADO_SELECCIONADO" == *D* ]]; then
    echo "El archivo fue eliminado."

else
    # --no-pager evita que Git quede detenido en una pantalla de diff
    git --no-pager diff -- "$ARCHIVO_SELECCIONADO" || true

    # Mostrar también cambios ya agregados previamente
    git --no-pager diff --cached -- "$ARCHIVO_SELECCIONADO" || true
fi

echo "--------------------------------------------------"
echo ""

read -r -p "¿Querés publicar este archivo? (s/n): " CONFIRMACION

case "$CONFIRMACION" in
    s|S|si|SI|Si|sí|Sí)
        ;;
    *)
        cancelar_operacion
        ;;
esac

# ==========================================================
# SOLICITAR MENSAJE DEL COMMIT
# ==========================================================

echo ""
read -r -p "Ingresá el mensaje del commit: " MENSAJE

# Eliminar espacios para validar si quedó vacío
MENSAJE_SIN_ESPACIOS="${MENSAJE//[[:space:]]/}"

if [ -z "$MENSAJE_SIN_ESPACIOS" ]; then
    mostrar_error "El mensaje del commit no puede estar vacío."
fi

# ==========================================================
# ACTUALIZAR REPOSITORIO
# ==========================================================

echo ""
echo "Actualizando información del repositorio remoto..."

git fetch "$REMOTO" || mostrar_error "No se pudo conectar con el repositorio remoto."

echo "✅ Información remota actualizada."
echo ""

# Verificar si hay cambios remotos
COMMITS_DETRAS=$(git rev-list --count "HEAD..$REMOTO/$RAMA" 2>/dev/null || echo "0")

if [ "$COMMITS_DETRAS" -gt 0 ]; then
    echo "Hay $COMMITS_DETRAS commit(s) nuevos en GitHub."
    echo "Actualizando el repositorio local..."
    echo ""

    # Autostash protege temporalmente los cambios locales
    git pull --rebase --autostash "$REMOTO" "$RAMA" ||
        mostrar_error "No se pudo actualizar el repositorio. Puede haber conflictos."

    echo "✅ Repositorio local actualizado."
    echo ""
else
    echo "✅ El repositorio local está actualizado."
    echo ""
fi

# ==========================================================
# AGREGAR ARCHIVO
# ==========================================================

echo "Agregando el archivo seleccionado..."

git add -- "$ARCHIVO_SELECCIONADO" ||
    mostrar_error "No se pudo agregar el archivo."

# Verificar que el archivo seleccionado tenga cambios preparados
if git diff --cached --quiet -- "$ARCHIVO_SELECCIONADO"; then
    mostrar_error "El archivo seleccionado no tiene cambios para guardar."
fi

echo "✅ Archivo agregado al área de preparación."
echo ""

# Mostrar resumen del commit
echo "Resumen del archivo preparado:"
echo "--------------------------------------------------"
git --no-pager diff --cached --stat -- "$ARCHIVO_SELECCIONADO"
echo "--------------------------------------------------"
echo ""

# ==========================================================
# CREAR COMMIT
# ==========================================================

echo "Creando commit..."

git commit -m "$MENSAJE" -- "$ARCHIVO_SELECCIONADO" ||
    mostrar_error "No se pudo crear el commit."

echo ""
echo "✅ Commit creado correctamente."
echo ""

# ==========================================================
# PUBLICAR EN GITHUB
# ==========================================================

echo "Publicando en GitHub..."

git push "$REMOTO" "$RAMA" ||
    mostrar_error "No se pudo publicar el commit en GitHub."

# ==========================================================
# RESULTADO
# ==========================================================

echo ""
echo "=================================================="
echo "       ✅ ARCHIVO PUBLICADO CORRECTAMENTE"
echo "=================================================="
echo ""
echo "Repositorio: $RUTA_REPOSITORIO"
echo "Remoto:      $URL_REMOTO"
echo "Rama:        $RAMA"
echo "Archivo:     $ARCHIVO_SELECCIONADO"
echo "Mensaje:     $MENSAJE"
echo ""
echo "Último commit:"
git --no-pager log -1 --oneline
echo ""

pausar
>>>>>>> 38ea140 (Actualizo script subir.sh)
