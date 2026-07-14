## Extraer los niveles del factor de magnitudes ----
niveles_grupos <- levels(sismos_sf$magnitud_grupo)

## Crear una lista de checkboxes HTML dinámicamente ----
opciones_checkbox_html <- paste0(
  '<label style="display: block; margin-bottom: 6px; font-size: 12px; color: #333; cursor: pointer; user-select: none;">',
  '<input type="checkbox" class="filtro-grupo-chk" value="', niveles_grupos, '" checked style="margin-right: 6px; vertical-align: middle; cursor: pointer;">',
  niveles_grupos,
  '</label>',
  collapse = '\n'
)

## Ensamblar usando <details> y <summary> para el efecto desplegable nativo ----
filtro_mag_html <- paste0(
  '<details id="control-filtro-magnitud" style="background: white; padding: 10px; border-radius: 5px; box-shadow: 0 1px 5px rgba(0,0,0,0.4); font-family: Arial, sans-serif; min-width: 160px; user-select: none;">',
  # El elemento <summary> actúa como el botón del menú desplegable
  '<summary style="font-weight: bold; font-size: 13px; color: #333; cursor: pointer; outline: none; display: flex; justify-content: space-between; align-items: center;">',
  'Filtrar por Grupo <span style="font-size: 9px; color: #888; margin-left: 8px;">▼</span>',
  '</summary>',
  # Contenedor interno que se ocultará/mostrará. Incluye scroll por si hay muchos elementos
  '<div class="menu-content" style="margin-top: 8px; border-top: 1px solid #eee; padding-top: 8px; max-height: 150px; overflow-y: auto;">',
  opciones_checkbox_html,
  '</div>',
  '</details>'
)

## Crear minigráfico con magnitudes ----
html_minigrafico <- '
  <div id="contenedor-grafico" style="margin-top: 12px; border-top: 1px solid #ddd; padding-top: 10px;">
    <span style="font-weight: bold; font-size: 11px; color: #555; display: block; margin-bottom: 6px;">
      Distribución de Magnitudes Activas:
    </span>
    <div id="css-bar-chart" style="
      display: flex; 
      justify-content: space-between; 
      align-items: flex-end; 
      height: 65px; 
      padding-bottom: 4px;
      border-bottom: 2px solid #aaa;
    ">
      </div>
  </div>
'
## Unificar panel para filtro de magnitudes y minigráfico ----
panel_unificado <- paste0(
  '<div id="contenedor-unificado" style="position: relative; font-family: sans-serif;">
  
  <button id="btn-toggle-panel" style="
    background-color: white; 
    border: 2px solid rgba(0,0,0,0.2); 
    border-radius: 4px; 
    padding: 6px 12px; 
    cursor: pointer; 
    font-weight: bold; 
    font-size: 12px;
    color: #333;
    display: flex;
    align-items: center;
    gap: 6px;
    box-shadow: 0 1px 5px rgba(0,0,0,0.4);
  ">
    📊 Filtro y gráfico
  </button>

  <div id="panel-contenido" style="
    display: none; 
    background: white; 
    padding: 12px; 
    border-radius: 4px; 
    box-shadow: 0 1px 5px rgba(0,0,0,0.4);
    width: 210px;
    margin-top: 5px;
    position: absolute;
    left: 0;
    z-index: 1000;
  ">',
  filtro_mag_html,
  html_minigrafico,
  '</div>'
)

## Sidebar para la navegación del sitio ----
html_sidebar <- htmltools::HTML('
<aside class="sidebar">
    <div class="sidebar-brand">
        <h2>Sismos VE</h2>
        <p class="made-by">Creado por <a href="https://github.com/itsmiguelrojas" target="_blank">@itsmiguelrojas</a></p>
    </div>
    <ul class="sidebar-links">
        <li>
            <a href="#" class="active">
                <span>📡</span> Monitoreo Principal
            </a>
        </li>
        <li>
            <a href="estadisticas/">
                <span>📊</span> Estadística Descriptiva
            </a>
        </li>
    </ul>
</aside>
')