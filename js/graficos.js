const geojsonUrl = 'https://raw.githubusercontent.com/itsmiguelrojas/seismic_monitor/refs/heads/main/sismos.geojson';

let seismicData = [];
let uniqueDates = [];
let uniqueGroups = []; 
let dailyStats = {}; 
let chartInstanceBar = null;
let chartInstanceLine = null; 
let chartInstanceBox = null; // Instancia global para el control del gráfico de Boxplot

const colorPalette = {
    'Baja': '#3498db',
    'Moderada': '#2ecc71',
    'Fuerte': '#e67e22',
    'Crítica': '#e74c3c',
    'Otros': '#9b59b6'
};

// Elementos del DOM
const loadingEl = document.getElementById('loading');
const dashboardEl = document.getElementById('dashboard');
const errorEl = document.getElementById('error');
const sliderStart = document.getElementById('date-slider-start');
const sliderEnd = document.getElementById('date-slider-end');
const currentDateDisplay = document.getElementById('current-date-display');
const startDateEl = document.getElementById('start-date');
const endDateEl = document.getElementById('end-date');
const checkboxesContainer = document.getElementById('group-checkboxes-container'); 

const ctxBar = document.getElementById('magnitudeChart').getContext('2d');
const ctxLine = document.getElementById('lineChart').getContext('2d'); 
const ctxBoxPlot = document.getElementById('boxPlotChart').getContext('2d'); // Contexto del lienzo Boxplot

// Extrae estrictamente el string de fecha (AAAA-MM-DD)
function extractDateString(propValue) {
    if (!propValue) return null;
    if (typeof propValue === 'string' && /^\d{4}-\d{2}-\d{2}/.test(propValue)) {
        return propValue.substring(0, 10);
    }
    const d = new Date(propValue);
    if (!isNaN(d.getTime())) {
        return d.toISOString().substring(0, 10);
    }
    return null;
}

async function init() {
    try {
        const response = await fetch(geojsonUrl);
        if (!response.ok) throw new Error('No se pudo descargar el archivo GeoJSON.');
        
        const geojson = await response.json();
        if (!geojson.features || geojson.features.length === 0) {
            throw new Error('El archivo GeoJSON no contiene un arreglo de features válido.');
        }

        const groupsSet = new Set(); 
        const dataByDate = {}; // Auxiliar para agrupar las magnitudes brutas por fecha

        geojson.features.forEach(feature => {
            const p = feature.properties || {};
            const rawMag = p.magnitud !== undefined ? p.magnitud : (p.mag !== undefined ? p.mag : p.magnitude);
            const rawDate = p.fecha !== undefined ? p.fecha : (p.time !== undefined ? p.time : p.date);
            const rawGroup = p.magnitud_grupo !== undefined ? p.magnitud_grupo : 'Otros';
            
            if (rawMag !== undefined && rawMag !== null) {
                const mag = parseFloat(rawMag);
                
                if (!isNaN(mag) && mag % 1 !== 0) {
                    const dateStr = extractDateString(rawDate);
                    if (dateStr) {
                        groupsSet.add(rawGroup);
                        
                        // [CAMBIO 1] Extraemos y formateamos la marca de tiempo continuo (Fecha y Hora)
                        let dateTimeStr = dateStr;
                        let timestamp = 0;
                        const d = new Date(rawDate);
                        if (!isNaN(d.getTime())) {
                            timestamp = d.getTime();
                            const pad = (n) => String(n).padStart(2, '0');
                            dateTimeStr = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
                        }
                        
                        seismicData.push({
                            magnitude: Math.round(mag * 10) / 10,
                            dateStr: dateStr,
                            dateTimeStr: dateTimeStr, // Guardamos la cadena continua
                            group: rawGroup,
                            timestamp: timestamp       // Guardamos el número para ordenar
                        });

                        if (!dataByDate[dateStr]) dataByDate[dateStr] = [];
                        dataByDate[dateStr].push(mag);
                    }
                }
            }
        });

        // [CAMBIO 2] Ordenamos cronológicamente de forma estricta para evitar saltos en la línea continua
        seismicData.sort((a, b) => a.timestamp - b.timestamp);

        if (seismicData.length === 0) {
            throw new Error('No se encontraron sismos con magnitudes continuas en el dataset.');
        }

        uniqueDates = Array.from(new Set(seismicData.map(d => d.dateStr))).sort();
        uniqueGroups = Array.from(groupsSet).sort(); 

        // Cómputo global inicial de estadísticas por cada día cronológico
        uniqueDates.forEach(date => {
            const magnitudes = dataByDate[date];
            const n = magnitudes.length;
            const sum = magnitudes.reduce((a, b) => a + b, 0);
            const avg = sum / n;
            
            const variance = magnitudes.reduce((a, b) => a + Math.pow(b - avg, 2), 0) / n;
            const stdDev = Math.sqrt(variance);

            dailyStats[date] = {
                avg: Math.round(avg * 100) / 100,
                std: Math.round(stdDev * 100) / 100,
                rawMagnitudes: magnitudes // Almacenamos el array bruto para alimentar el Boxplot
            };
        });

        // Construcción dinámica de Checkboxes para los grupos de magnitud
        uniqueGroups.forEach(groupName => {
            const label = document.createElement('label');
            label.className = 'checkbox-label';
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.value = groupName;
            checkbox.checked = true; 
            checkbox.addEventListener('change', updateDashboard); 
            
            const dotColor = colorPalette[groupName] || '#7f8c8d';
            label.style.borderLeft = `4px solid ${dotColor}`;
            
            label.appendChild(checkbox);
            label.appendChild(document.createTextNode(` ${groupName}`));
            checkboxesContainer.appendChild(label);
        });

        sliderStart.min = 0;    
        sliderStart.max = uniqueDates.length - 1;
        sliderStart.value = 0; // El asa izquierda inicia al principio

        sliderEnd.min = 0;
        sliderEnd.max = uniqueDates.length - 1;
        sliderEnd.value = uniqueDates.length - 1; // El asa derecha inicia al final
        
        startDateEl.textContent = uniqueDates[0];
        endDateEl.textContent = uniqueDates[uniqueDates.length - 1];

        loadingEl.style.display = 'none';
        dashboardEl.style.display = 'block';

        sliderStart.addEventListener('input', updateDashboard);
        sliderEnd.addEventListener('input', updateDashboard);
        updateDashboard();

    } catch (err) {
        loadingEl.style.display = 'none';
        errorEl.textContent = `Error: ${err.message}`;
        errorEl.style.display = 'block';
        console.error(err);
    }
}

function updateDashboard() {
    // Validación para evitar que el slider de inicio supere al de fin
    if (parseInt(sliderStart.value) > parseInt(sliderEnd.value)) {
        sliderStart.value = sliderEnd.value;
    }

    const startIndex = parseInt(sliderStart.value);
    const endIndex = parseInt(sliderEnd.value);

    const startDate = uniqueDates[startIndex];
    const endDate = uniqueDates[endIndex];

    // Mostramos el rango seleccionado en el texto del dashboard
    currentDateDisplay.textContent = `${startDate} a ${endDate}`;

    // Acotamos el array de fechas discretas entre ambos índices
    const visibleDates = uniqueDates.slice(startIndex, endIndex + 1);

    // =========================================================================
    // 1. PROCESAMIENTO Y ACTUALIZACIÓN DEL GRÁFICO DE BARRAS
    // =========================================================================
    const checkedBoxes = Array.from(checkboxesContainer.querySelectorAll('input[type="checkbox"]:checked'));
    const selectedGroups = checkedBoxes.map(cb => cb.value);
    
    const filteredDataBar = seismicData.filter(d => d.dateStr >= startDate && d.dateStr <= endDate && selectedGroups.includes(d.group));

    const counts = {};
    filteredDataBar.forEach(d => {
        counts[d.magnitude] = (counts[d.magnitude] || 0) + 1;
    });
    const sortedMagnitudes = Object.keys(counts).map(Number).sort((a, b) => a - b);
    const frequencies = sortedMagnitudes.map(mag => counts[mag]);

    if (chartInstanceBar) {
        chartInstanceBar.data.labels = sortedMagnitudes.map(m => m.toFixed(1));
        chartInstanceBar.data.datasets[0].data = frequencies;
        chartInstanceBar.update();
    } else {
        chartInstanceBar = new Chart(ctxBar, {
            type: 'bar',
            data: {
                labels: sortedMagnitudes.map(m => m.toFixed(1)),
                datasets: [{
                    label: 'Frecuencia de sismos',
                    data: frequencies,
                    backgroundColor: 'rgba(52, 152, 219, 0.75)',
                    borderColor: 'rgba(52, 152, 219, 1)',
                    borderWidth: 1,
                    borderRadius: 4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: { y: {
                  title: { display: true, text: 'Frecuencia', font: { weight: 'bold' } },
                  beginAtZero: true,
                  ticks: { precision: 0 }
                },
                          x : {
                  title: { display: true, text: 'Magnitud (Mw)', font: { weight: 'bold' } }
                          }}
            }
        });
    }

    // =========================================================================
    // 2. PROCESAMIENTO Y ACTUALIZACIÓN DEL GRÁFICO DE LÍNEAS (SERIE DE TIEMPO CONTINUA)
    // =========================================================================
    const lineFilteredData = seismicData.filter(d => d.dateStr >= startDate && d.dateStr <= endDate);
    
    // Mapeo estructurado de magnitudes absolutas individuales
    const lineChartData = lineFilteredData.map(d => ({
        x: d.dateTimeStr, 
        y: d.magnitude
    }));

    const lineLabels = lineFilteredData.map(d => d.dateTimeStr);

    if (chartInstanceLine) {
        chartInstanceLine.data.labels = lineLabels;
        chartInstanceLine.data.datasets[0].data = lineChartData;
        chartInstanceLine.update();
    } else {
        chartInstanceLine = new Chart(ctxLine, {
            type: 'line',
            data: {
                labels: lineLabels,
                datasets: [{
                    label: 'Magnitud de sismo',
                    data: lineChartData,
                    borderColor: '#3498db',         
                    backgroundColor: 'rgba(231, 76, 60, 0.05)',
                    borderWidth: 1.5,
                    pointRadius: 0,
                    tension: 0, 
                    fill: false
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        enabled: false
                    }
                },
                scales: {
                    x: {
                        type: 'category', 
                        title: { display: true, text: 'Tiempo (fecha y hora)', font: { weight: 'bold' } },
                        ticks: {
                            maxTicksLimit: 8 
                        }
                    },
                    y: {
                        title: { display: true, text: 'Magnitud (Mw)', font: { weight: 'bold' } },
                        beginAtZero: true,
                        suggestedMax: 5
                    }
                }
            }
        });
    }

    // =========================================================================
    // 3. PROCESAMIENTO Y ACTUALIZACIÓN DEL GRÁFICO DE BBOXPLOT + JITTER PLOT
    // =========================================================================
    const boxPlotData = visibleDates.map(date => dailyStats[date].rawMagnitudes || []);

    if (chartInstanceBox) {
        chartInstanceBox.data.labels = visibleDates;
        chartInstanceBox.data.datasets[0].data = boxPlotData;
        chartInstanceBox.update();
    } else {
        chartInstanceBox = new Chart(ctxBoxPlot, {
            type: 'boxplot',
            data: {
                labels: visibleDates,
                datasets: [{
                    label: 'Distribución de magnitudes',
                    data: boxPlotData,
                    backgroundColor: 'rgba(52, 152, 219, 0.4)', 
                    borderColor: '#3498db',
                    borderWidth: 1.5,
                    outlierBackgroundColor: '#e74c3c',
                    outlierRadius: 2.5,
                    
                    // Configuración del Jitter Plot (Renderizado de los puntos individuales distribuidos aleatoriamente)
                    itemRadius: 2.5,
                    itemStyle: 'circle',
                    itemBackgroundColor: 'rgba(44, 62, 80, 0.2)', 
                    itemBorderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        
                    }
                },
                scales: {
                    x: {
                        type: 'category',
                        title: { display: true, text: 'Cronología (Fechas)', font: { weight: 'bold' } }
                    },
                    y: {
                        title: { display: true, text: 'Magnitud (Mw)', font: { weight: 'bold' } },
                        beginAtZero: true,
                        suggestedMax: 5 
                    }
                }
            }
        });
    }
}

init();