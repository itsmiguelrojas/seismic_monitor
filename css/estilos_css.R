estilo_adicional <- tags$style(HTML('
  .info.legend.leaflet-control:has(#contenedor-unificado) {
    margin-top: 5em !important;
  }
  
  .leaflet-control.map-title {
    margin-top: 1.2em !important;
  }
  
  .menu-content {
    height: 100px;
  }
  
  @media (max-width: 768px) {
  .leaflet-control.map-title {
    display: none !important;
  }
  
  .info.legend.leaflet-control:has(#contenedor-unificado) {
    margin-top: 10px !important;
  }
  
  div#panel-contenido {
    width: 210px !important;
  }
}
'))