## Validaciones automáticas

El generador realiza una serie de validaciones antes de comenzar la creación de la solución.

### Validación del entorno

- Comprueba que .NET SDK esté instalado y disponible en el PATH.
- Identifica la versión activa del SDK.
- Comprueba que la versión mayor del SDK sea igual o superior a la versión mayor del framework objetivo.
- Valida el formato del Target Framework seleccionado.

### Validación de parámetros

- Verifica que el nombre de la solución sea válido.
- Comprueba que el framework de pruebas sea xUnit, NUnit o MSTest.
- Rechaza argumentos adicionales no permitidos.

### Validación de plantillas

Antes de generar cualquier archivo, utiliza `dotnet new --dry-run` para comprobar que las siguientes plantillas estén disponibles y admitan el framework solicitado:

- `webapi`
- `classlib`
- `xunit`, `nunit` o `mstest`, según la selección.

Esto permite detectar problemas de compatibilidad antes de modificar el directorio de trabajo.

### Protección de archivos existentes

- Comprueba que no exista una solución con el mismo nombre.
- Verifica que los directorios de proyectos no existan previamente.
- Evita sobrescribir archivos o proyectos existentes.

## Manejo de errores y limpieza automática

Si ocurre un error durante la generación de la solución, configuración de referencias o restauración de dependencias, el generador ejecuta un proceso de limpieza.

Este proceso:

1. Identifica los directorios de proyectos generados durante la ejecución.
2. Elimina los proyectos creados por el generador.
3. Elimina el archivo de solución generado.
4. Elimina los directorios `src` y `test` únicamente cuando fueron creados por el generador y quedaron vacíos.
5. Conserva los archivos y directorios preexistentes.

De esta manera, se evita dejar una solución parcialmente generada.

**Nota:** la limpieza contempla los archivos generados dentro del directorio de trabajo. No elimina paquetes descargados en la caché global de NuGet.

## Ayuda del generador

Puedes consultar los argumentos disponibles y ejemplos de ejecución:

```bash
./generate.sh --help
```

También puedes utilizar:

```bash
./generate.sh -h
```

## Consideraciones

- Ejecutar el script desde el directorio donde se desea crear la solución.
- Verificar que el SDK activo sea compatible con el framework seleccionado.
- Mantener instaladas las plantillas correspondientes al SDK.
- La validación previa comprueba la disponibilidad y compatibilidad de las plantillas, pero no garantiza que la restauración de paquetes NuGet o la compilación posterior sean exitosas.
- La limpieza automática protege los archivos preexistentes y elimina los artefactos generados por una ejecución fallida.
- La plantilla genera la estructura inicial y las referencias entre proyectos; no implementa funcionalidades de negocio.