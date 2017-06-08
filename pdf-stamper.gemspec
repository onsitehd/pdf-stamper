Gem::Specification.new do |s|
  s.name = %q{pdf-stamper}
  s.version = "0.6.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Jason Yates", "Marshall Anschutz", 'Aaron Breckenridge']
  s.date = %q{2013-10-28}
  s.description = %q{Fill out PDF forms (templates) using iText's PdfStamper.}
  s.email = %q{jaywhy@gmail.com}
  s.extra_rdoc_files = ["History.txt", "Manifest.txt"]
  s.files = ["History.txt", "Manifest.txt", "README.md", "Rakefile", "ext/iText-4.2.0.jar", "lib/pdf/stamper.rb", "lib/pdf/stamper/jruby.rb", "lib/pdf/stamper/rjb.rb", "spec/logo.gif", "spec/pdf_stamper_spec.rb", "spec/test_template.pdf"]
  s.homepage = %q{http://github.com/jaywhy/pdf-stamper/}
  s.require_paths = ["lib", "ext"]
  s.rubyforge_project = %q{pdf-stamper}
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{PDF templates using iText's PdfStamper.}
  s.add_development_dependency('rspec', '3.6.0')
end
