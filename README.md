# CoALoseControl

CoALoseControl es un addon para Conquest of Azeroth (Ascension) que muestra alertas visuales cuando tu personaje queda afectado por efectos de control de masas (CC) como stuns, fears, silences, roots y otros efectos similares.

Además, incluye un sistema de aprendizaje automático capaz de detectar y guardar nuevos CC que encuentre durante el juego, ayudando a mantener la base de datos actualizada incluso cuando se añaden nuevas habilidades al servidor.

## Características

* Alertas visuales cuando recibes un efecto de control.
* Detección automática de nuevos CC.
* Base de datos integrada con efectos conocidos.
* Gestión sencilla mediante comandos.
* Configuración desde el menú de interfaz.
* Botón opcional en el minimapa para acceso rápido.
* Configuración y datos guardados entre sesiones.

## Instalación

1. Descarga el addon.
2. Extrae la carpeta **CoALoseControl** dentro de:

```text
Ascension/Launcher/resources/ascension-live/Interface/AddOns/
```

3. Verifica que la estructura final sea:

```text
AddOns/
└── CoALoseControl/
    ├── CoALoseControl.toc
    ├── LoseControl.lua
    └── CoALoseControlData.lua
```

4. Inicia el juego o utiliza `/reload`.

## Configuración

Abre el panel desde:

```text
Esc → Interface → AddOns → CoALoseControl
```

Opciones disponibles:

* Activar o desactivar el aprendizaje automático.
* Permitir que se registren nuevos CC.
* Mostrar u ocultar alertas visuales.
* Mostrar u ocultar el icono del minimapa.

También puedes acceder rápidamente mediante el botón del minimapa si está habilitado.

## Comandos

| Comando       | Descripción                                                   |
| ------------- | ------------------------------------------------------------- |
| `/lc options` | Abre el panel de configuración.                               |
| `/lc list`    | Muestra los CC conocidos y aprendidos.                        |
| `/lc learn`   | Activa o desactiva el aprendizaje automático.                 |
| `/lc reset`   | Borra los CC aprendidos y reinicia la base de datos dinámica. |
| `/lc 12345`   | Añade manualmente un Spell ID a la base de datos.             |

## Cómo funciona

El addon monitoriza los buffs y debuffs aplicados al jugador y compara sus Spell IDs con una base de datos de efectos de control conocidos.

Cuando el aprendizaje automático está activado, CoALoseControl también analiza nuevas habilidades detectadas y puede registrarlas automáticamente para futuras sesiones.

Los datos aprendidos se almacenan localmente en la configuración guardada del personaje.

## Archivos principales

* **CoALoseControl.toc** — Información y carga del addon.
* **LoseControl.lua** — Lógica principal, interfaz y detección de CC.
* **CoALoseControlData.lua** — Base de datos de controles conocidos.

## Solución de problemas

**El addon no aparece en el juego**

* Comprueba que la carpeta se llame exactamente `CoALoseControl`.
* Verifica que `CoALoseControl.toc` esté dentro de esa carpeta.

**Las alertas no aparecen**

* Revisa que la opción de alertas esté activada en la configuración.
* Ejecuta `/reload` tras instalar o actualizar el addon.

**He movido el icono del minimapa**

* Su posición se guarda automáticamente y se restaurará al volver a iniciar sesión.

## Compatibilidad

Desarrollado para Conquest of Azeroth (Ascension) utilizando la interfaz compatible con `30300`.

