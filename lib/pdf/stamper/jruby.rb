# = pdf/stamper/rjb.rb -- PDF template stamping.
#
#  Copyright (c) 2007-2009 Jason Yates

$:.unshift(File.join(File.dirname(__FILE__), '..', '..', '..', 'ext'))
require 'java'
require 'itext5-itextpdf-5.5.11.jar'

java_import 'java.io.FileOutputStream'
java_import 'java.io.ByteArrayOutputStream'
java_import 'com.itextpdf.text.pdf.AcroFields'
java_import 'com.itextpdf.text.pdf.PdfReader'
java_import 'com.itextpdf.text.pdf.PdfStamper'
java_import 'com.itextpdf.text.Image'
java_import 'com.itextpdf.text.Rectangle'
java_import 'com.itextpdf.text.pdf.GrayColor'
java_import 'com.itextpdf.text.BaseColor'

module PDF
  include_package 'com.itextpdf.text.pdf'

  class Stamper
    def initialize(pdf = nil)
      template(pdf) if ! pdf.nil?
    end

    BLACK = BaseColor::BLACK
  
    def template(template)
      # NOTE I'd rather use a ByteArrayOutputStream.  However I
      # couldn't get it working.  Patches welcome.
      #@tmp_path = File.join(Dir::tmpdir, 'pdf-stamper-' + rand(10000).to_s + '.pdf')
      @reader = PDF::PdfReader.new(template)
      @baos = ByteArrayOutputStream.new
      @stamp = PDF::PdfStamper.new(@reader, @baos)#FileOutputStream.new(@tmp_path))
      @form = @stamp.getAcroFields()
      @black = GrayColor.new(0.0)
      @canvas = @stamp.getOverContent(1)
    end
    
    def is_checkbox(field_type)
      field_type == AcroFields::FIELD_TYPE_CHECKBOX
    end
  
    # Set a button field defined by key and replaces with an image.
    def image(key, image_path)
      # Idea from here http://itext.ugent.be/library/question.php?id=31 
      # Thanks Bruno for letting me know about it.
      img = Image.getInstance(image_path)
      img_field = @form.getFieldPositions(key.to_s)

      rect = Rectangle.new(img_field[1], img_field[2], img_field[3], img_field[4])
      img.scaleToFit(rect.width, rect.height)
      img.setAbsolutePosition(
        img_field[1] + (rect.width - img.scaledWidth) / 2,
        img_field[2] + (rect.height - img.scaledHeight) /2
      )

      cb = @stamp.getOverContent(img_field[0].to_i)
      cb.addImage(img)
    end

    def create_barcode(format)
      PDF.const_get("Barcode#{format}").new
    end

    def create_rectangle(coords)
      Rectangle.new(coords[1], coords[2], coords[3], coords[4])
    end

    def create_font(font_name)
      BaseFont.createFont(font_name, BaseFont.CP1252, false)
    end
    
    # Takes the PDF output and sends as a string.  Basically it's sole
    # purpose is to be used with send_data in rails.
    def to_s
      fill
      String.from_java_bytes(@baos.toByteArray)
    end
  end
end
