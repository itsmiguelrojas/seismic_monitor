estilo_adicional <- tags$style(HTML('
  .leaflet-control.map-title {
    margin-top: 1.2em !important;
  }
  
  .menu-content {
    height: 100px;
  }
  
  @media (max-width: 855px) {
  .leaflet-control.map-title {
    display: none !important;
  }
  
  div#panel-contenido {
    width: 210px !important;
  }
}
'))