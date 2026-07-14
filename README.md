# CoALoseControl para CoA Ascension

CoALoseControl muestra un aviso visual cuando tu personaje recibe control de personaje (CC). También aprende automáticamente nuevos IDs de CC a partir de los auras que detecta.

## Instalación
1. Copia la carpeta `CoALoseControl` en la ruta de addons de tu cliente de CoA Ascension:
   - Windows: `Ascension/Launcher/resources/ascension-live/Interface/AddOns`
   - Ajusta la ruta según tu instalación si tu cliente está en otra carpeta.
2. Reinicia el juego o usa `/reload` dentro del juego.

## Uso
### Panel de opciones
- Abre la interfaz de AddOns en el juego (`Esc > Interface > AddOns > CoALoseControl`).
- Activa o desactiva:
  - Autoaprendizaje de CC
  - Permitir aprendizaje
  - Mostrar alertas de CC
  - Mostrar icono en minimapa
- Usa el botón del minimapa para abrir el panel de opciones directamente.

### Comandos
- `/lc 12345` añade un ID manualmente.
- `/lc list` muestra los CC conocidos y los aprendidos.
- `/lc reset` reinicia la base de datos aprendida.
- `/lc learn` activa o desactiva el aprendizaje automático.
- `/lc options` abre el panel de opciones.

## Qué hace
- Detecta auras del jugador y revisa los `spellId` de buffs/debuffs.
- Usa una base predefinida de CC (`CoALoseControlData.lua`).
- Aprende nuevos IDs de CC basados en nombres de efectos que parecen controles.
- Guarda los datos aprendidos en `LoseControlDB`.

## Archivos principales
- `CoALoseControl.toc` — manifiesto del addon.
- `LoseControl.lua` — lógica principal, detección, aprendizaje y UI.
- `CoALoseControlData.lua` — base de datos de IDs de CC.

## Notas
- Si el addon no aparece en la lista, asegúrate de que la carpeta se llame exactamente `CoALoseControl` y que contenga `CoALoseControl.toc`.
- Si cambias la posición del icono del minimapa, se guarda automáticamente en la configuración.
- El addon es compatible con el cliente de Ascension que usa `## Interface: 30300`.
