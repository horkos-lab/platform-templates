# ${{ values.projectTitle }}

${{ values.projectDescription }}

## Detalles del Proyecto

| Campo | Valor |
|---|---|
| **Identificador** | `${{ values.projectName }}` |
| **Tipo** | ${{ values.projectType }} |
| **Cliente** | ${{ values.clientRef }} |
| **Estado del ciclo de vida** | ${{ values.lifecycle }} |

## Arquitectura

_Documenta aquí la arquitectura del proyecto._

## Componentes

Los componentes de este sistema se registran individualmente en el Catalog
con `spec.system: ${{ values.projectName }}`.

## Guías de Operación

_Agrega aquí runbooks, guías de despliegue y procedimientos operativos._
