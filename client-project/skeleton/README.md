# ${{ values.projectTitle }}

${{ values.projectDescription }}

## Información del Proyecto

| Campo | Valor |
|---|---|
| **Proyecto** | ${{ values.projectTitle }} |
| **Tipo** | ${{ values.projectType }} |
| **Cliente** | ${{ values.clientRef }} |
| **Estado** | ${{ values.lifecycle }} |

## Estructura del Repositorio

```
.
├── catalog-info.yaml    # Definición de la entidad en Backstage
├── mkdocs.yml           # Configuración de TechDocs
├── docs/
│   └── index.md         # Documentación del proyecto
└── README.md            # Este archivo
```

## Registro en Backstage

Este proyecto está registrado en el Catalog de Backstage como un `System`.
Los servicios y componentes de este proyecto deben declarar:

```yaml
spec:
  system: ${{ values.projectName }}
  owner: ${{ values.clientRef }}
```

## Documentación

La documentación técnica del proyecto se publica automáticamente en TechDocs.
Para agregar contenido, edita los archivos en el directorio `docs/`.
