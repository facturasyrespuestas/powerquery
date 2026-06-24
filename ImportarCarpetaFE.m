let
    /* 
    Cambie esta ruta por la carpeta donde se encuentran sus facturas electrónicas 
    */
    RutaFacturas = "*** INGRESE LA RUTA DE SU CARPETA DE FACTURAS AQUÍ ***",

    /* 
    Esta es la lista de campos que se extraerán de la cada factura, ajustela de acuerdo con los campos
    que retorne la función  ExtraerDatosFactura
    */
    ListaCampos =  { "CUFE", "NumeroFactura", "FechaEmision", "HoraEmision", "Notas", "FormaPago", "MedioPago",
                    "EmisorNombre","EmisorNIT","AdquirienteNombre","AdquirienteNIT","ValorTotal" },

    /* Obtiene el valor de un elemento dado el elemento padre y el nombre del elemento Hijo */
    ValorElemento = (Padre, NombreHijo) => try  Table.SelectRows( Padre, each [Name] = NombreHijo ){0}[Value] otherwise null,

    /* Obtiene un elemento hijo el elemento padre y el nombre del elemento Hijo */
    HijoElemento = (Padre, NombreHijo) => try  Table.SelectRows( Padre, each [Name] = NombreHijo ){0}[Value] otherwise null,

    /* 
    
    Esta es la función principal que extrae los campos de la factura electrónica 
    
    Si necesita agregar más campos, modifique esta función para obtenerlos de la ruta respectiva
    dentro del XML
    
    */
    ExtraerDatosFactura = ( XML ) =>
    let
        Invoice =  Xml.Document(XML),

        Root = Invoice{0}[Value],
        // Encabezado
        UUID       = ValorElemento( Root, "UUID"),
        ID         = ValorElemento( Root, "ID"),
        IssueDate  = ValorElemento( Root, "IssueDate"),
        IssueTime  = ValorElemento( Root, "IssueTime"),
        Note       = ValorElemento( Root, "Note"),

        // Forma de Pago : PaymentMeans 
        PaymentMeans     = HijoElemento( Root, "PaymentMeans" ),
        PaymentMeansID   = ValorElemento( PaymentMeans, "ID"),
        PaymentMeansCode = ValorElemento( PaymentMeans, "PaymentMeansCode"),

        // Emisor : AccountingSupplierParty
        AccountingSupplierParty = HijoElemento( Root, "AccountingSupplierParty" ),
        SupplierParty           = HijoElemento( HijoElemento( AccountingSupplierParty, "Party" ), "PartyTaxScheme" ),
        SupplierPartyName       = ValorElemento( SupplierParty, "RegistrationName" ),
        SupplierID              = ValorElemento( SupplierParty, "CompanyID"),

        // Adquiriente : AccountingCustomerParty
        AccountingCustomerParty = HijoElemento( Root, "AccountingCustomerParty" ),
        CustomerParty           = HijoElemento( HijoElemento( AccountingCustomerParty, "Party"), "PartyTaxScheme" ),
        CustomerPartyName       = ValorElemento( CustomerParty, "RegistrationName" ),
        CustomerID              = ValorElemento( CustomerParty, "CompanyID"),

        // Totales : LegalMonetaryTotal
        LegalMonetaryTotal      = HijoElemento( Root, "LegalMonetaryTotal" ),
        PayableAmount           = ValorElemento( LegalMonetaryTotal, "PayableAmount" )

    in
        [
            CUFE             = UUID,
            NumeroFactura     = ID,
            FechaEmision      = IssueDate,
            HoraEmision       = IssueTime,
            Notas             = Note,
            FormaPago         = PaymentMeansID,
            MedioPago         = PaymentMeansCode,
            EmisorNombre      = SupplierPartyName,
            EmisorNIT         = SupplierID, 
            AdquirienteNombre = CustomerPartyName,
            AdquirienteNIT    = CustomerID,
            ValorTotal        = PayableAmount
        ],

    /*  
    
    Extrae el Documento XML que viene adjunto dentro de un AttachedDocument
    
    */
    ObtenerXMLAdjunto =  ( Contenido ) =>  let
        AD = Xml.Document( Contenido ),
        AttachedDocument = AD{0}[Value] ,
        Attachment = Table.SelectRows( AttachedDocument, each [Name] = "Attachment" ),
        ExternalReference = Table.SelectRows( Attachment{0}[Value], each [Name] = "ExternalReference" ),
        Description = Table.SelectRows( ExternalReference{0}[Value], each [Name] = "Description" ),
        Document = Description{0}[Value]
    in
        Document   ,    

    /*
    
    Función principal

    */
    Todos = Folder.Files( RutaFacturas ),
    Filtrados = Table.SelectRows(Todos, each Text.Lower([Extension]) = ".xml"),
    Adjuntos = Table.AddColumn(Filtrados, "xml", each ObtenerXMLAdjunto([Content])),
    Campos = Table.AddColumn(Adjuntos, "campos", each ExtraerDatosFactura([xml])),
    Expandidas = Table.ExpandRecordColumn(Campos, "campos", ListaCampos, ListaCampos),
    Final = Table.RemoveColumns(Expandidas,{"Content", "Name", "Extension", "Date accessed", "Date modified", "Date created", "Attributes", "Folder Path", "xml"})
in
    Final