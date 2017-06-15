$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require 'pdf/stamper'

describe PDF::Stamper do
  it 'should create PDF document' do
    PDF::Stamper.new(File.join(File.dirname(__FILE__), 'test_template.pdf')).to_s.should_not be_nil
  end

  it 'should save PDF document' do
    pdf = PDF::Stamper.new(File.join(File.dirname(__FILE__), 'test_template.pdf'))
    pdf.text :text_field01, 'test'
    pdf.text :text_field02, 'test2'
    pdf.image :button_field01, File.join(File.dirname(__FILE__), 'logo.gif')
    pdf.save_as 'test_output.pdf'
    File.exist?('test_output.pdf').should be true
    File.delete('test_output.pdf')
  end

  it 'should generate PDF417 barcodes' do
    pdf = PDF::Stamper.new(File.join(File.dirname(__FILE__), 'test_template.pdf'))
    pdf.barcode('PDF417', :text_field01, 'this is a barcode')
    pdf.save_as('barcode_output.pdf')
    File.exist?('barcode_output.pdf').should be true
    File.delete('barcode_output.pdf')
  end

  it 'should ignore datamatrix for invalid fieldnames' do
    pdf = PDF::Stamper.new(File.join(File.dirname(__FILE__), 'test_template.pdf'))
    pdf.datamatrix('this field does not exist', 'this is a barcode')
  end

  it 'should stamp any pages in the document' do
    pdf = PDF::Stamper.new(File.join(File.dirname(__FILE__), 'multipage_fields.pdf'))
    pdf.datamatrix('APPOINTMENT_DATA', 'Hello, world!')
    pdf.save_as('datamatrix_output.pdf')
    File.exist?('datamatrix_output.pdf').should be true
    File.delete('datamatrix_output.pdf')
  end
end
