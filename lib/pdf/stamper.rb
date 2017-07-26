# = pdf/stamper.rb -- PDF template stamping.
#
#  Copyright (c) 2007-2012 Jason Yates

require 'rbconfig'
require 'fileutils'
#require 'tmpdir'
#require 'active_support/inflector/methods'

include FileUtils

require 'pdf/stamper/jruby'

module PDF
  class Stamper
    VERSION = "0.6.0"
    
    
    # PDF::Stamper provides an interface into iText's PdfStamper allowing for the
    # editing of existing PDFs as templates. PDF::Stamper is not a PDF generator,
    # it allows you to edit existing PDFs and use them as templates.
    #
    # == Creation of templates
    #
    # Templates currently can be created using Adobe LiveCycle Designer
    # or Adobe Acrobat Professional. Using Acrobat Professional, you can create
    # a form and add textfields, checkboxes, radio buttons and buttons for images.
    #
    # == Example
    #
    # pdf = PDF::Stamper.new("my_template.pdf")
    # pdf.text :first_name, "Jason"
    # pdf.text :last_name, "Yates"
    # pdf.image :photo, "photo.jpg"
    # pdf.checkbox :hungry
    # pdf.save_as "my_output"

    def initialize(pdf = nil)
      template(pdf) if ! pdf.nil?
    end
  
    def template(template)
      @reader = PdfReader.new(template)
      @baos = ByteArrayOutputStream.new
      @stamp = PdfStamper.new(@reader, @baos)
      @form = @stamp.getAcroFields()
      @canvas = @stamp.getOverContent(1)
    end
  
    # Set a button field defined by key and replaces with an image.
    def image(key, image_path, options = {})
      # Idea from here http://itext.ugent.be/library/question.php?id=31 
      # Thanks Bruno for letting me know about it.
      img = Image.get_instance(image_path)
      coords = @form.get_field_positions(key.to_s)
      rect = coords[0].position
      img.set_absolute_position(rect.left, rect.bottom)
      img.scale_to_fit(rect)
      image_content = @stamp.get_over_content(options.fetch(:page, 1))
      image_content.add_image(img)
    end
    
    # PDF::Stamper allows setting metadata on the created PDF by passing
    # the parameters to the set_more_info function. Our implementation here
    # is slightly different from iText, in that we only receive a single key/value
    # pair at a time, instead of a Map<string,string> since that is slightly
    # more complex to bridge properly from ruby to java.
    # 
    # Possible keys include "Creator". All values here are strings.
    # 
    def set_metadata(key, value)
      params = java.util.HashMap.new()
      params.put(key.to_s, value)
      @stamp.setMoreInfo(params)
    end
    
    # If you want to have iText reset some of the metadata, this function will
    # cause iText to use its default xml metadata.
    def reset_xmp_metadata()
      @stamp.setXmpMetadata("".to_java_bytes)
    end
    
    # Set a textfield defined by key and text to value
    def text(key, value)
      @form.setField(key.to_s, value.to_s) # Value must be a string or itext will error.
    end

    
    # Takes the PDF output and sends as a string.
    #
    # Here is how to use it in rails:
    #
    # def send 
    #     pdf = PDF::Stamper.new("sample.pdf") 
    #     pdf.text :first_name, "Jason"
    #     pdf.text :last_name, "Yates" 
    #     send_data(pdf.to_s, :filename => "output.pdf", :type => "application/pdf",:disposition => "inline")
    # end   
    def to_s
      fill
      String.from_java_bytes(@baos.toByteArray)
    end


    # Set a checkbox to checked
    def checkbox(key)
      field_type = @form.getFieldType(key.to_s)
      return unless is_checkbox(field_type)

      all_states = @form.getAppearanceStates(key.to_s)
      yes_state = all_states.reject{|x| x == "Off"}
      
      
      @form.setField(key.to_s, yes_state.first) unless (yes_state.size == 0)
    end
    
    # Get checkbox values
    def get_checkbox_values(key)
      field_type = @form.getFieldType(key.to_s)
      return unless is_checkbox(field_type)

      @form.getAppearanceStates(key.to_s)
    end

    def circle(x, y, r)
      @canvas.circle(x, y, r)
    end

    def ellipse(x, y, width, height)
      @canvas.ellipse(x, y, x + width, y + height)
    end

    def rectangle(x, y,  width, height)
      @canvas.rectangle(x, y, width, height)
    end

    # Generate a Datamatrix barcode and stamp it over the specified form field.
    #
    # @param form_field [String] The name of the PDF form field where the
    #   barcode will be drawn.
    # @param value [String] The value of the Datamatrix barcode.
    # @optional height [Integer] The number of 'rows' in the barcode.
    # @optional width [Integer] The number of 'columns' in the barcode.
    # @optional module_height [Numeric] Set the module height
    # @optional module_width [Numeric] Set the module width
    #
    # @example Add a datamatrix barcode to a PDF over the form_field_name form field:
    #   pdf.datamatrix('form_field_name', 'your text here', height: 16, width: 48)
    def datamatrix(form_field, value, opts = {})
      bar = create_barcode('Datamatrix')
      bar.set_height(opts.fetch(:height, 0))
      bar.set_width(opts.fetch(:width, 0))
      bar.generate(value)
      bar_image = bar.create_image # only used to set the containing template size

      coords = @form.getFieldPositions(form_field.to_s)
      return unless coords
      coords.each do |coord|
        rect = coord.position
        # BarcodeDatamatrix#getImage returns an image that is unpleasantly
        # rasterized by some PDF viewers. Using BarcodeDatamatrix#place_barcode
        # ensures a clearly legible Datamatrix barcode, but requires jumping
        # through a template hoop. PDF417 does not exhibit this quality
        # degredation.
        stamp_content = @stamp.get_over_content(opts.fetch(:page, coord.page))
        template = stamp_content.create_template(bar_image.width, bar_image.height)
        bar.place_barcode(template, BLACK, opts.fetch(:module_height, 1), opts.fetch(:module_width, 1))
        image = Image.get_instance(template)
        image.set_absolute_position(rect.left, rect.bottom)
        image.scale_to_fit(rect)
        stamp_content.add_image(image, false)
      end
    end

    # @example Add a PDF417 barcode:
    #
    #   barcode("PDF417", "2d_barcode", "Barcode data...", AspectRatio: 0.5)
    def barcode(format, key, value, opts = {})
      bar = create_barcode(format)
      bar.setText(value)
      opts.each do |name, opt|
        bar.send("set#{name.to_s}", opt)
      end
      coords = @form.getFieldPositions(key.to_s)
      return unless coords
      coords.each do |coord|
        rect = coord.position
        barcode_img = bar.get_image
        barcode_img.scale_to_fit(rect)
        barcode_img.set_absolute_position(rect.left, rect.bottom)
        cb = @stamp.get_over_content(opts.fetch(:page, coord.page))
        cb.add_image(barcode_img)
      end
    end

    # this has to be called *before* setting field values
    def set_font(font_name)
      itr = @form.getFields.keySet.iterator
      while itr.hasNext
        field = itr.next
        @form.setFieldProperty(field, 'textfont', create_font(font_name), nil)
      end
    end
    
    # Saves the PDF into a file defined by path given. If you want to save
    # to a string/buffer, just use .to_s directly.
    def save_as(file)
      File.open(file, "wb") { |f| f.write to_s }
    end
    
    private

    def fill
      @canvas.stroke()
      @stamp.setFormFlattening(true)
      @stamp.close
      @reader.close
    end
  end
end
