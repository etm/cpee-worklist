### All code in this file is provided under the LGPL license. Please read the file COPYING.
class HTML
  def initialize(title)
    @res = ''
    @title = title
    @css = ''
    @js = ''
    @html = File.read(File.expand_path(File.dirname(__FILE__) + '/html.template'))
    @level = 0
    @buf = {}
  end
  def add_css(name,content)
    @css << " " * 6 << name << " {\n" << content.gsub(/^\s*/, ' ' * 8) << " " * 6 << "}\n"
  end
  def add_js(content)
    @js << content.gsub(/^\s*/, ' ' * 6) << "\n"
  end

  def add(content)
    @res << content
  end

  def add_tag(name,attr = {})
    str = ''
    str << "<#{name}" + (attr.empty? ? '' : ' ' + (attr.collect{ |key,value| value.nil? ? nil : "#{key}=\"#{value.to_s.gsub(/"/,"&#34;")}\"" }.compact.join(" "))) + ">"
    @level += 1
    str << yield.to_s.strip if block_given?
    @buf[@level] = ''
    @level -= 1
    str << "</#{name}>\n"
    if @level == 0
      str
    else  
      @buf[@level] ||= ''
      @buf[@level] << str
    end  
  end

  def dump
    (@html % [@title,@css,@js,@res]).gsub(/\n+/,"\n")
  end  
end
