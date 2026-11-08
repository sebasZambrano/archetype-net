#!/bin/bash

set -Eeuo pipefail

# ============================================================
# CONFIGURACIÓN
# ============================================================

solutionName="${1:-MyApp}"
targetFramework="${2:-net8.0}"
testFramework="${3:-xunit}"

srcDir="src"
testDir="test"

testTemplate=""

generationStarted=0
srcDirExisted=0
testDirExisted=0

# ============================================================
# FUNCIONES GENERALES
# ============================================================

print_error() {
    echo ""
    echo "❌ ERROR: $1" >&2
    exit 1
}

print_success() {
    echo "✅ $1"
}

show_usage() {
    cat <<EOF

.NET HEXAGONAL ARCHITECTURE GENERATOR

Uso:
  ./generate.sh [NombreSolucion] [Framework] [TestFramework]

Argumentos:

  NombreSolucion    Nombre de la solución. Por defecto: MyApp
  Framework         Target Framework. Por defecto: net8.0
  TestFramework     xunit, nunit o mstest. Por defecto: xunit

Ejemplos:

  ./generate.sh
  ./generate.sh MyApp net8.0 xunit
  ./generate.sh Inventory net9.0 nunit
  ./generate.sh Hospital net10.0 mstest

Opciones:

  -h, --help        Muestra esta ayuda.

Frameworks de pruebas disponibles:

  xunit
  nunit
  mstest

EOF
}

# ============================================================
# MANEJO DE ERRORES Y LIMPIEZA
# ============================================================

on_error() {
    local exitCode="$1"
    local lineNumber="$2"
    local failedCommand="$3"

    echo ""
    echo "❌ Error durante la ejecución."
    echo "📌 Línea: $lineNumber"
    echo "📌 Comando: $failedCommand"
    echo "📌 Código de salida: $exitCode"

    exit "$exitCode"
}

cleanup() {
    local exitCode=$?

    if (( exitCode != 0 && generationStarted == 1 )); then

        echo ""
        echo "🧹 Limpiando archivos generados durante la ejecución fallida..."

        rm -rf -- \
            "$srcDir/$solutionName.Api" \
            "$srcDir/$solutionName.Application" \
            "$srcDir/$solutionName.Domain" \
            "$srcDir/$solutionName.Infrastructure" \
            "$testDir/$solutionName.Tests"

        rm -f -- \
            "$solutionName.sln" \
            "$solutionName.slnx"

        # Eliminar carpetas únicamente si fueron creadas
        # por esta ejecución y quedaron vacías.

        if (( srcDirExisted == 0 )); then
            rmdir "$srcDir" 2>/dev/null || true
        fi

        if (( testDirExisted == 0 )); then
            rmdir "$testDir" 2>/dev/null || true
        fi

        echo "🧹 Limpieza finalizada."
        echo "⚠️ No se modificaron archivos preexistentes."
    fi

    return "$exitCode"
}

trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
trap cleanup EXIT

# ============================================================
# VALIDACIÓN DEL NOMBRE
# ============================================================

validate_project_name() {
    if [[ ! "$solutionName" =~ ^[a-zA-Z][a-zA-Z0-9]*$ ]]; then
        print_error "Nombre inválido: '$solutionName'. Utiliza letras y números, comenzando por una letra."
    fi
}

# ============================================================
# VALIDACIÓN DEL FRAMEWORK .NET
# ============================================================

validate_framework() {
    if [[ ! "$targetFramework" =~ ^net([1-9][0-9]*)\.0$ ]]; then
        print_error "Framework inválido: '$targetFramework'. Ejemplos: net8.0, net9.0, net10.0."
    fi

    local targetMajor="${BASH_REMATCH[1]}"
    local sdkVersion
    local sdkMajor

    sdkVersion=$(dotnet --version)
    sdkMajor="${sdkVersion%%.*}"

    if [[ ! "$sdkMajor" =~ ^[0-9]+$ ]]; then
        print_error "No fue posible identificar la versión activa del SDK."
    fi

    if (( sdkMajor < targetMajor )); then
        print_error "El SDK $sdkVersion no es suficiente para el framework $targetFramework."
    fi

    echo "📌 SDK activo: $sdkVersion"
    echo "📌 Framework objetivo: $targetFramework"
}

# ============================================================
# VALIDACIÓN DEL FRAMEWORK DE PRUEBAS
# ============================================================

validate_test_framework() {
    case "$testFramework" in
        xunit)
            testTemplate="xunit"
            ;;
        nunit)
            testTemplate="nunit"
            ;;
        mstest)
            testTemplate="mstest"
            ;;
        *)
            print_error "Framework de pruebas inválido: '$testFramework'. Opciones: xunit, nunit o mstest."
            ;;
    esac
}

# ============================================================
# VALIDACIÓN DE DIRECTORIOS Y ARCHIVOS EXISTENTES
# ============================================================

validate_existing_files() {

    if [[ -e "$solutionName.sln" || -e "$solutionName.slnx" ]]; then
        print_error "Ya existe una solución con el nombre '$solutionName'."
    fi

    local projects=(
        "$srcDir/$solutionName.Api"
        "$srcDir/$solutionName.Application"
        "$srcDir/$solutionName.Domain"
        "$srcDir/$solutionName.Infrastructure"
        "$testDir/$solutionName.Tests"
    )

    for project in "${projects[@]}"; do
        if [[ -e "$project" ]]; then
            print_error "Ya existe el directorio '$project'. No se sobrescribirán archivos."
        fi
    done

    if [[ -e "$srcDir" ]]; then
        srcDirExisted=1
    fi

    if [[ -e "$testDir" ]]; then
        testDirExisted=1
    fi
}

# ============================================================
# VALIDACIÓN PREVIA DE PLANTILLAS
# ============================================================

validate_templates() {

    local tempDir

    tempDir=$(mktemp -d) || \
        print_error "No fue posible crear el directorio temporal para validar las plantillas."

    echo ""
    echo "🔍 Validando disponibilidad de plantillas..."

    local templates=(
        "webapi"
        "classlib"
        "$testTemplate"
    )

    local templateNames=(
        "API"
        "Class Library"
        "Testing ($testFramework)"
    )

    local index=0

    for template in "${templates[@]}"; do

        echo "🔍 Validando plantilla: ${templateNames[$index]}..."

        if ! dotnet new "$template" \
            --name "TemplateValidation" \
            --output "$tempDir/$template" \
            --framework "$targetFramework" \
            --dry-run \
            > /dev/null 2>&1; then

            rm -rf -- "$tempDir"

            print_error "La plantilla '$template' no está disponible o no admite el framework '$targetFramework'. Verifica el SDK y las plantillas instaladas."
        fi

        print_success "Plantilla '$template' validada."

        ((index += 1))
    done

    rm -rf -- "$tempDir"

    print_success "Todas las plantillas son compatibles."
}

# ============================================================
# CREACIÓN DE PROYECTOS
# ============================================================

create_project() {

    local template="$1"
    local projectName="$2"
    local outputDir="$3"

    echo ""
    echo "🚀 Creando proyecto: $projectName"

    dotnet new "$template" \
        --name "$projectName" \
        --output "$outputDir" \
        --framework "$targetFramework"
}

# ============================================================
# VALIDACIONES INICIALES
# ============================================================

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

if (( $# > 3 )); then
    show_usage
    print_error "Se recibieron más argumentos de los permitidos."
fi

echo "============================================================"
echo "       .NET HEXAGONAL ARCHITECTURE GENERATOR"
echo "============================================================"

command -v dotnet >/dev/null 2>&1 || \
    print_error ".NET SDK no está instalado o no está disponible en el PATH."

validate_project_name
validate_framework
validate_test_framework
validate_existing_files

# ============================================================
# VALIDACIÓN PREVIA ANTES DE MODIFICAR EL DIRECTORIO
# ============================================================

validate_templates

# A partir de aquí comienza la generación real.
generationStarted=1

# ============================================================
# CREACIÓN DE DIRECTORIOS
# ============================================================

echo ""
echo "📁 Creando estructura de carpetas..."

mkdir -p "$srcDir" "$testDir"

# ============================================================
# CREACIÓN DE LA SOLUCIÓN
# ============================================================

echo ""
echo "📦 Creando solución..."

dotnet new sln --name "$solutionName"

if [[ -f "$solutionName.sln" ]]; then
    solutionFile="$solutionName.sln"
elif [[ -f "$solutionName.slnx" ]]; then
    solutionFile="$solutionName.slnx"
else
    print_error "No fue posible localizar el archivo de solución generado."
fi

# ============================================================
# CREACIÓN DE PROYECTOS
# ============================================================

create_project "webapi" \
    "$solutionName.Api" \
    "$srcDir/$solutionName.Api"

create_project "classlib" \
    "$solutionName.Application" \
    "$srcDir/$solutionName.Application"

create_project "classlib" \
    "$solutionName.Domain" \
    "$srcDir/$solutionName.Domain"

create_project "classlib" \
    "$solutionName.Infrastructure" \
    "$srcDir/$solutionName.Infrastructure"

# ============================================================
# CREACIÓN DEL PROYECTO DE PRUEBAS
# ============================================================

echo ""
echo "🧪 Framework de pruebas: $testFramework"

create_project "$testTemplate" \
    "$solutionName.Tests" \
    "$testDir/$solutionName.Tests"

# ============================================================
# REFERENCIAS ENTRE PROYECTOS
# ============================================================

echo ""
echo "🔗 Configurando referencias entre proyectos..."

dotnet add "$srcDir/$solutionName.Application/$solutionName.Application.csproj" \
    reference "$srcDir/$solutionName.Domain/$solutionName.Domain.csproj"

dotnet add "$srcDir/$solutionName.Infrastructure/$solutionName.Infrastructure.csproj" \
    reference \
    "$srcDir/$solutionName.Application/$solutionName.Application.csproj" \
    "$srcDir/$solutionName.Domain/$solutionName.Domain.csproj"

dotnet add "$srcDir/$solutionName.Api/$solutionName.Api.csproj" \
    reference \
    "$srcDir/$solutionName.Application/$solutionName.Application.csproj" \
    "$srcDir/$solutionName.Infrastructure/$solutionName.Infrastructure.csproj"

dotnet add "$testDir/$solutionName.Tests/$solutionName.Tests.csproj" \
    reference \
    "$srcDir/$solutionName.Domain/$solutionName.Domain.csproj" \
    "$srcDir/$solutionName.Application/$solutionName.Application.csproj"

# ============================================================
# AGREGAR PROYECTOS A LA SOLUCIÓN
# ============================================================

echo ""
echo "📌 Agregando proyectos a la solución..."

dotnet sln "$solutionFile" add \
    "$srcDir/$solutionName.Api/$solutionName.Api.csproj" \
    "$srcDir/$solutionName.Application/$solutionName.Application.csproj" \
    "$srcDir/$solutionName.Domain/$solutionName.Domain.csproj" \
    "$srcDir/$solutionName.Infrastructure/$solutionName.Infrastructure.csproj" \
    "$testDir/$solutionName.Tests/$solutionName.Tests.csproj"

# ============================================================
# RESTAURACIÓN DE DEPENDENCIAS
# ============================================================

echo ""
echo "📦 Restaurando dependencias..."

dotnet restore "$solutionFile"

# ============================================================
# RESULTADO FINAL
# ============================================================

echo ""
echo "============================================================"
print_success "Solución '$solutionName' generada correctamente."
echo "============================================================"

echo "📌 SDK: $(dotnet --version)"
echo "📌 Framework: $targetFramework"
echo "📌 Test Framework: $testFramework"
echo "📌 Solución: $solutionFile"

echo ""
echo "📂 Estructura generada:"
echo "   ├── $srcDir/"
echo "   │   ├── $solutionName.Api/"
echo "   │   ├── $solutionName.Application/"
echo "   │   ├── $solutionName.Domain/"
echo "   │   └── $solutionName.Infrastructure/"
echo "   ├── $testDir/"
echo "   │   └── $solutionName.Tests/"
echo "   └── $solutionFile"

echo ""
echo "Para ejecutar la API:"
echo "cd $srcDir/$solutionName.Api && dotnet run"

echo ""
echo "Para ejecutar las pruebas:"
echo "dotnet test $solutionFile"

echo ""
print_success "Proceso finalizado correctamente."