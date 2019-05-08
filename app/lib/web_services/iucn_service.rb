class IUCNService

  attr_accessor :datos, :row, :validacion

  # Consulta la categoria de riesgo de un taxon dado
  def consultaRiesgo(opts)
    @iucn = CONFIG.iucn.api
    @token = CONFIG.iucn.token

    url = "#{@iucn}/api/v3/species/#{opts[:nombre].limpia_ws}?token=#{@token}"
    url_escape = URI.escape(url)
    uri = URI.parse(url_escape)
    req = Net::HTTP::Get.new(uri.to_s)
    begin
      res = Net::HTTP.start(uri.host, uri.port, :read_timeout => CONFIG.iucn.timeout ) {|http| http.request(req) }
      jres = JSON.parse(res.body)['result']
      jres[0]['category'] if jres.any?
    rescue => e
      nil
    end
  end

  # Guarda en cache la respuesta del servicio
  def dameRiesgo(opc={})
    resp = Rails.cache.fetch("iucn_#{opc[:id]}", expires_in: eval(CONFIG.cache.iucn)) do
      iucn = consultaRiesgo(opc)
      I18n.t("iucn_ws.#{iucn.estandariza}", :default => iucn) if iucn.present?
    end

    resp
  end

  # Accede al archivo que contiene los assessments y la taxonomia dentro de la carpeta versiones_IUCN
  # NOTAS: Este archivo se baja de la pagina de IUCN y hay que unir el archivo de asswessments con el de taxonomy
  def actualiza_IUCN(archivo)
    csv_path = Rails.root.join('public', 'IUCN', archivo)
    bitacora.puts 'Nombre científico en IUCN,Categoría en IUCN,Nombre en CAT,IdCAT,Estatus nombre,IdCAT válido,Nombre válido CAT,observaciones'
    return unless File.exists? csv_path

    CSV.foreach(csv_path, :headers => true) do |r|
      self.row = r
      self.datos = []
      self.datos[0] = row['scientificName']
      self.datos[1] = row['redlistCategory']

      v = Validacion.new
      v.nombre_cientifico = datos[0]
      v.encuentra_por_nombre
      self.validacion = v.validacion
      self.datos[7] = validacion[:msg]

      if validacion[:estatus]  # Hubo al menos una coincidencia
        if validacion[:taxon].present?  # Solo un resultado
          valida_extras
        elsif v[:taxones].present?  # Mas de un resultado
          #self.datos[7] = validacion[:msg]
        end
      end



=begin
      t = Especie.where(nombre_cientifico: row['scientificName'])

      if t.length == 1  # Caso más sencillo
        estatus = t.first.estatus
        self.datos[2] = t.first.nombre_cientifico
        self.datos[3] = t.first.scat.catalogo_id
        self.datos[4] = estatus

        if estatus == 2  # Quiere decir que es valido
          mismo_reino?(t.first)
          misma_categoria?(t.first) if datos[5].present?
        elsif estatus == 1
          if taxon_valido = t.first.dame_taxon_valido
            mismo_reino?(taxon_valido)
            self.datos[7] = 'Es un sinónimo y encontró el válido' if datos[5].present?
          else
            self.datos[7] = 'Es un sinónimo y hubo problemas al encontrar el válido'
          end
        end

      elsif t.length == 0 # Sin resultados
        # Intento el nombre separandolo
        if row['infraType'].blank?
          self.datos[7] = 'Sin coincidencias (especie)'
        else  # Limpio el nombre cientifico y trato de encontrar por separado el trinomio
          nombres = datos[0].limpiar.split(' ')
          taxon = Especie.where("LOWER(#{Especie.attribute_alias(:nombre_cientifico)}) LIKE '#{nombres[0]}%#{nombres[1]}%#{nombres[2]}'")

          if taxon.length == 1
          else

          end
        end

      else  # Más de un resultado, puede haber homonimias o simplemente un sinonimo se llama igual
        validos = 0

        t.each do |taxon|
          next if taxon.estatus != 2
          validos+= 1
          mismo_reino?(taxon)
          misma_categoria?(taxon) if datos[5].present?
        end

        # Por si deberás hay una homonimia
        self.datos[7] = 'Más de un resultado (homonímia)' + t.map(&:id).join('|') if validos >= 2 || validos == 0
      end
=end
      bitacora.puts datos.join(',')
    end

    bitacora.close
  end


  private

  # Bitacora especial para catalogos, antes de correr en real, pasarsela
  def bitacora
    log_path = Rails.root.join('log', Time.now.strftime('%Y-%m-%d_%H%m') + '_IUCN.csv')
    @@bitacora ||= File.new(log_path, 'a+')
  end

  # Valida que los reinos coincidan para evitar homonimos
  def mismo_reino?
    reino = validacion[:taxon].root.nombre_cientifico.estandariza

    if row['kingdomName'].estandariza == reino  # Si coincidio el reino y es un valido
      return true
    else  # Los reinos no coincidieron
      self.datos[7] = 'Los reinos no coincidieron'
      return false
    end
  end

  # Valida que la categoria taxonomica sea la misma
  def misma_categoria?
    categorias = { 'subspecies' => 'subespecie', 'subspecies-plantae' => 'subespecie', 'variety' => 'variedad' }

    categoria = if row['infraType'].blank?
                  'especie'
                else
                  categorias[row['infraType'].estandariza]
                end

    cat_taxon = validacion[:taxon].categoria_taxonomica.nombre_categoria_taxonomica.estandariza

    unless cat_taxon == categoria
      self.datos[7] = 'La categoria taxonómica no coincidio'
    end
  end

  # Asigna el nombre valido en caso de ser un sinonimo
  def dame_el_valido
    if validacion[:taxon].estatus == 1
      if taxon_valido = validacion[:taxon].dame_taxon_valido
        validacion[:taxon] = taxon_valido
        self.datos[5] = validacion[:taxon].scat.catalogo_id
        self.datos[6] = validacion[:taxon].nombre_cientifico
        self.datos[7] = 'Es un sinónimo y encontró el válido'
        return true
      else
        self.datos[7] = 'Es un sinónimo y hubo problemas al encontrar el válido'
        return false
      end

    elsif validacion[:taxon].estatus == 2
      self.datos[5] = validacion[:taxon].scat.catalogo_id
      self.datos[6] = validacion[:taxon].nombre_cientifico
      return true
    end
  end

  # Valida el nombre y categoría taxonomica
  def valida_extras
    self.datos[2] = validacion[:taxon].nombre_cientifico
    self.datos[3] = validacion[:taxon].scat.catalogo_id
    self.datos[4] = validacion[:taxon].estatus
    self.datos[7] = validacion[:msg]

    return unless mismo_reino?
    return unless dame_el_valido

    misma_categoria?
  end

end

