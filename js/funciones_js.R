## Script de JavaScript para controlador y contador dinámico ----
js_contador <- "
function(el, x) {
      var map = this;
      
      // 1. Crear y definir el contenedor personalizado en el mapa
      var counterControl = L.control({position: 'bottomright'});
      
      counterControl.onAdd = function (map) {
        this._div = L.DomUtil.create('div', 'dynamic-counter-box'); 
        
        // Estilos CSS directos para dar apariencia de widget o caja de visualización
        this._div.style.backgroundColor = 'rgba(255, 255, 255, 0.95)';
        this._div.style.padding = '12px 16px';
        this._div.style.borderRadius = '8px';
        this._div.style.boxShadow = '0 3px 8px rgba(0,0,0,0.25)';
        this._div.style.fontSize = '13px';
        this._div.style.fontFamily = 'Helvetica, Arial, sans-serif';
        this._div.style.color = '#2c3e50';
        this._div.style.border = '1px solid #bdc3c7';
        this._div.style.lineHeight = '1.6';
        
        this.update(0, 'N/A', 'N/A');
        return this._div;
      };
      
      // Función interna para actualizar el código HTML según los datos calculados
      counterControl.update = function (count, start, finish) {
        this._div.innerHTML = 
          '<div style=\"font-weight: bold; font-size: 14px; margin-bottom: 6px; border-bottom: 2px solid #ecf0f1; padding-bottom: 4px;\">📊 Ventana sísmica</div>' +
          '🔢 <b>Eventos registrados:</b> ' + count + '<br>' +
          '⏱️ <b>Desde:</b> <span style=\"color: #2980b9; font-weight: bold;\">' + start + '</span><br>' +
          '🏁 <b>Hasta:</b> <span style=\"color: #c0392b; font-weight: bold;\">' + finish + '</span>';
      };
      
      counterControl.addTo(map);
      
      // 2. Lógica para rastrear, extraer y ordenar marcas temporales del mapa en vivo
      var countTimeout;
      function recalculateRecords() {
        clearTimeout(countTimeout);
        
        // Retrasar el cálculo 40ms para asegurar fluidez de fotogramas al arrastrar el slider
        countTimeout = setTimeout(function() {
          var count = 0;
          var activeTimes = []; // Matriz contenedora de marcas de tiempo visibles
          
          map.eachLayer(function (layer) {
            // Validamos el sismo por su magnitud para no perder los 'sin fecha'
            if (layer.feature && layer.feature.properties && typeof layer.feature.properties.magnitud !== 'undefined') {
              count++; // Se incluye con éxito en el conteo de 'Eventos registrados'
              
              // Solo si la propiedad fecha es válida, se añade para el cálculo de los extremos del rango
              if (layer.feature.properties.fecha) {
                activeTimes.push(layer.feature.properties.fecha);
              }
            }
          });
          
          var startTime = 'N/A';
          var finishTime = 'N/A';
          
          // Si hay capas visibles en pantalla, ordenar alfabéticamente para hallar los límites temporales
          if (activeTimes.length > 0) {
            activeTimes.sort(); // Alphabetic sort works perfectly for YYYY-MM-DD HH:MM:SS structures
            startTime = activeTimes[0];
            finishTime = activeTimes[activeTimes.length - 1];
          }
          
          // Enviar los resultados finales a la interfaz gráfica de la caja
          counterControl.update(count, startTime, finishTime);
        }, 40); // 40ms debounce to optimize render scrolling frame rates
      }
      
      // 3. Capturar eventos de adición/remoción de capas generados por el Timeslider
      map.on('layeradd layerremove', function(e) {
        if (e.layer && e.layer.feature) {
          recalculateRecords();
        }
      });
      // Ejecutar inicialización única al cargar por primera vez el mapa
      recalculateRecords();
    }
"

## Script de JavaScript para filtrar magnitudes ----
js_filtro_magnitud <- "
function(el, x) {
  var map = this;

  // Seleccionar los elementos del nuevo panel unificado
  var contenedorUnificado = el.querySelector('#contenedor-unificado');
  var btnToggle = el.querySelector('#btn-toggle-panel');
  var panelContenido = el.querySelector('#panel-contenido');
  var contenedorFiltro = el.querySelector('#control-filtro-magnitud');

  // 1. CONTROL DE APERTURA/CIERRE (TOGGLE)
  if (btnToggle && panelContenido) {
    btnToggle.addEventListener('click', function() {
      if (panelContenido.style.display === 'none' || panelContenido.style.display === '') {
        panelContenido.style.display = 'block';
        btnToggle.style.backgroundColor = '#f0f0f0'; // Cambio sutil de color al estar abierto
        actualizarMinigrafico(map); // Refrescar gráfico al abrir
      } else {
        panelContenido.style.display = 'none';
        btnToggle.style.backgroundColor = 'white';
      }
    });
  }

  // 2. BLINDAJE INTERACTIVO: Evitar que clics o scroll afecten al mapa de fondo
  if (contenedorUnificado) {
    L.DomEvent.disableClickPropagation(contenedorUnificado);
    L.DomEvent.disableScrollPropagation(contenedorUnificado);
  }

  // ==========================================
  // FUNCIÓN: GENERACIÓN DEL MINIGRÁFICO
  // ==========================================
  function actualizarMinigrafico(mapaObj) {
    var frecuencias = {};
    
    mapaObj.eachLayer(function(layer) {
      if (layer.feature && layer.feature.properties && typeof layer.feature.properties.magnitud !== 'undefined') {
        if (layer.getRadius && layer.getRadius() > 0) {
          var mag = parseFloat(layer.feature.properties.magnitud).toFixed(1);
          frecuencias[mag] = (frecuencias[mag] || 0) + 1;
        }
      }
    });

    var magnitudesOrdenadas = Object.keys(frecuencias).sort(function(a, b) {
      return parseFloat(a) - parseFloat(b);
    });

    var maxFrecuencia = 0;
    magnitudesOrdenadas.forEach(function(mag) {
      if (frecuencias[mag] > maxFrecuencia) maxFrecuencia = frecuencias[mag];
    });

    var graficoContenedor = document.getElementById('css-bar-chart');
    if (!graficoContenedor) return;
    
    var htmlBarras = '';
    var anchoBarra = Math.max(2, Math.floor(100 / magnitudesOrdenadas.length) - 2);

    magnitudesOrdenadas.forEach(function(mag) {
      var conteo = frecuencias[mag];
      var alturaPorcentaje = maxFrecuencia > 0 ? (conteo / maxFrecuencia) * 100 : 0;

      htmlBarras += `
        <div class=\"barra-css\" 
             title=\"Magnitud: ${mag} (${conteo} sismos)\" 
             style=\"
               height: ${alturaPorcentaje}%; 
               width: ${anchoBarra}%; 
               background-color: #19aeff; 
               border-radius: 2px 2px 0 0;
               transition: height 0.2s ease;
               cursor: pointer;
             \"
             onmouseover=\"this.style.backgroundColor='#0070ac'\"
             onmouseout=\"this.style.backgroundColor='#19aeff'\">
        </div>
      `;
    });

    graficoContenedor.innerHTML = htmlBarras || '<span style=\"font-size:10px; color:#aaa; margin:auto;\">Sin datos</span>';
  }

  // 3. LÓGICA DE FILTRADO GEOMETRÍAS
  function obtenerGruposActivos() {
    var checkboxes = el.querySelectorAll('.filtro-grupo-chk');
    var activos = [];
    checkboxes.forEach(function(chk) {
      if (chk.checked) activos.push(chk.value);
    });
    return activos;
  }

  function aplicarFiltro(layer) {
    if (layer.feature && layer.feature.properties && typeof layer.feature.properties.magnitud_grupo !== 'undefined') {
      var grupoSismo = layer.feature.properties.magnitud_grupo;
      var magFisica = layer.feature.properties.magnitud;
      var gruposSeleccionados = obtenerGruposActivos();
      var matches = gruposSeleccionados.includes(grupoSismo);

      if (matches) {
        if (layer.setRadius) layer.setRadius(magFisica * 2);
        if (layer.setStyle) layer.setStyle({ opacity: 0.5, fillOpacity: 0.8 });
        if (layer.getElement && layer.getElement()) layer.getElement().style.pointerEvents = 'auto';
      } else {
        if (layer.setRadius) layer.setRadius(0);
        if (layer.setStyle) layer.setStyle({ opacity: 0, fillOpacity: 0 });
        if (layer.getElement && layer.getElement()) layer.getElement().style.pointerEvents = 'none';
      }
    }
  }

  // Reactividad ante los checkboxes
  if (contenedorFiltro) {
    contenedorFiltro.addEventListener('change', function(e) {
      if (e.target.classList.contains('filtro-grupo-chk')) {
        map.eachLayer(function(layer) {
          aplicarFiltro(layer);
        });
        actualizarMinigrafico(map);
      }
    });
  }

  // Reactividad ante el deslizador temporal
  map.on('layeradd', function(e) {
    aplicarFiltro(e.layer);
    clearTimeout(window.timerGrafico);
    window.timerGrafico = setTimeout(function() {
      actualizarMinigrafico(map);
    }, 40);
  });

  // Disparador inicial de carga en segundo plano
  setTimeout(function() {
    actualizarMinigrafico(map);
  }, 200);
}
"