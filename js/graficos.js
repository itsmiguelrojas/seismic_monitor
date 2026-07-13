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
const slider = document.getElementById('date-slider');
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
                        
                        seismicData.push({
                            magnitude: Math.round(mag * 10) / 10,
                            dateStr: dateStr,
                            group: rawGroup
                        });

                        if (!dataByDate[dateStr]) dataByDate[dateStr] = [];
                        dataByDate[dateStr].push(mag);
                    }
                }
            }
        });

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

        slider.min = 0;
        slider.max = uniqueDates.length - 1;
        slider.value = uniqueDates.length - 1;
        
        startDateEl.textContent = uniqueDates[0];
        endDateEl.textContent = uniqueDates[uniqueDates.length - 1];

        loadingEl.style.display = 'none';
        dashboardEl.style.display = 'block';

        slider.addEventListener('input', updateDashboard);
        updateDashboard();

    } catch (err) {
        loadingEl.style.display = 'none';
        errorEl.textContent = `Error: ${err.message}`;
        errorEl.style.display = 'block';
        console.error(err);
    }
}

function updateDashboard() {
    const dateIndex = parseInt(slider.value);
    const selectedDate = uniqueDates[dateIndex];
    currentDateDisplay.textContent = selectedDate;

    // =========================================================================
    // 1. PROCESAMIENTO Y ACTUALIZACIÓN DEL GRÁFICO DE BARRAS
    // =========================================================================
    const checkedBoxes = Array.from(checkboxesContainer.querySelectorAll('input[type="checkbox"]:checked'));
    const selectedGroups = checkedBoxes.map(cb => cb.value);
    
    const filteredDataBar = seismicData.filter(d => d.dateStr <= selectedDate && selectedGroups.includes(d.group));

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
                    label: 'Frecuencia de Sismos',
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
                scales: { y: { beginAtZero: true, ticks: { precision: 0 } } }
            }
        });
    }

    // =========================================================================
    // 2. PROCESAMIENTO Y ACTUALIZACIÓN DEL GRÁFICO DE LÍNEAS
    // =========================================================================
    const visibleDates = uniqueDates.slice(0, dateIndex + 1);
    
    // Mapeo estructurado con 'x' explicita para evitar problemas de renderizado en Chart.js
    const lineChartData = visibleDates.map(date => ({
        x: date, 
        y: dailyStats[date].avg,
        std: dailyStats[date].std
    }));

    if (chartInstanceLine) {
        chartInstanceLine.data.labels = visibleDates;
        chartInstanceLine.data.datasets[0].data = lineChartData;
        chartInstanceLine.update();
    } else {
        chartInstanceLine = new Chart(ctxLine, {
            type: 'line',
            data: {
                labels: visibleDates,
                datasets: [{
                    label: 'Promedio de Magnitud',
                    data: lineChartData,
                    borderColor: '#e74c3c',         
                    backgroundColor: 'rgba(231, 76, 60, 0.08)',
                    borderWidth: 2,
                    pointRadius: 3,
                    pointBackgroundColor: '#e74c3c',
                    tension: 0.15,
                    fill: false
                }]
            },
            plugins: [{
                id: 'errorBarsPlugin',
                afterDatasetsDraw(chart) {
                    const { ctx, scales: { y } } = chart;
                    const meta = chart.getDatasetMeta(0); 
                    
                    if (meta.hidden) return;

                    meta.data.forEach((element, index) => {
                        const rawPoint = chart.data.datasets[0].data[index];
                        if (!rawPoint || rawPoint.std === undefined) return;

                        const xPx = element.x; 
                        const yTopPx = y.getPixelForValue(rawPoint.y + rawPoint.std);
                        const yBottomPx = y.getPixelForValue(rawPoint.y - rawPoint.std);

                        ctx.save();
                        ctx.strokeStyle = 'rgba(44, 62, 80, 0.65)'; 
                        ctx.lineWidth = 1.2;

                        ctx.beginPath();
                        ctx.moveTo(xPx, yTopPx);
                        ctx.lineTo(xPx, yBottomPx);
                        ctx.stroke();

                        const capWidth = 4;
                        ctx.beginPath();
                        ctx.moveTo(xPx - capWidth, yTopPx); ctx.lineTo(xPx + capWidth, yTopPx);
                        ctx.moveTo(xPx - capWidth, yBottomPx); ctx.lineTo(xPx + capWidth, yBottomPx);
                        ctx.stroke();

                        ctx.restore();
                    });
                }
            }],
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            // Tooltip modificado para incluir la frecuencia exacta calculada dinámicamente
                            label: function(context) {
                                const p = context.raw;
                                const fechaActual = p.x;
                                const frecuencia = seismicData.filter(d => d.dateStr === fechaActual).length;
                                return `Promedio: ${p.y.toFixed(2)} ± ${p.std.toFixed(2)} (Desv. Est.) | Frecuencia: ${frecuencia} sismos`;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        type: 'category', 
                        title: { display: true, text: 'Cronología (Fechas)', font: { weight: 'bold' } }
                    },
                    y: {
                        title: { display: true, text: 'Magnitud Escalar', font: { weight: 'bold' } },
                        beginAtZero: false,
                        suggestedMin: 0,
                        max: 5 // Escala extendida a 5 para evitar recortes en la barra superior de error
                    }
                }
            }
        });
    }

    // =========================================================================
    // 3. PROCESAMIENTO Y ACTUALIZACIÓN DEL GRÁFICO DE BOXPLOT + JITTER PLOT
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
                    label: 'Distribución de Magnitudes',
                    data: boxPlotData,
                    backgroundColor: 'rgba(52, 152, 219, 0.4)', 
                    borderColor: '#3498db',
                    borderWidth: 1.5,
                    outlierBackgroundColor: '#e74c3c',
                    
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
                        title: { display: true, text: 'Magnitud', font: { weight: 'bold' } },
                        beginAtZero: true,
                        suggestedMax: 5 // Mismo límite visual que el gráfico de líneas vecino para mantener simetría
                    }
                }
            }
        });
    }
}

init();