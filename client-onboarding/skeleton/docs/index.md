# ${{ values.clientTitle }}

Bienvenido al portal de documentación de **${{ values.clientTitle }}**.

## Información General

| Campo | Valor |
|---|---|
| **Cliente** | ${{ values.clientTitle }} |
| **Tipo de Engagement** | ${{ values.engagementType }} |
| **Segmento** | ${{ values.clientTier }} |
| **Región** | ${{ values.region }} |
| **Contacto Principal** | ${{ values.contactEmail }} |

## Proyectos Activos

Los proyectos asociados a este cliente aparecen automáticamente en el
[Catalog de Backstage](/) bajo la entidad `group:default/${{ values.clientName }}`.

## Recursos

- [Checklist de Onboarding](./onboarding-checklist.md)
- [Catalog Graph del Cliente](/)
