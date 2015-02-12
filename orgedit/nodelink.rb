#!/usr/bin/ruby
### All code in this file is provided under the LGPL license. Please read the file COPYING.
require 'rubygems'
require 'pp'
require 'optparse'
require File.expand_path(File.dirname(__FILE__) + '/lib/html')

### Commandline parsing # {{{
debug = false
ARGV.options { |opt|
  opt.summary_indent = ' ' * 2
  opt.banner = "Usage:\n#{opt.summary_indent}#{File.basename($0)} [options] [FILENAME]\n"
  opt.on("Options:")
  opt.on("--help", "-h", "This text") { puts opt; exit }
  opt.on("--verbose", "-v", "Verbose calculation of graph") { debug = true }
  opt.on("Example:\n#{opt.summary_indent}#{File.basename($0)} organisation.xml")
  opt.parse!
}
if ARGV.length == 0 || !File.exists?(ARGV[0])
  puts ARGV.options
  puts "File #{ARGV[0]} not found!"
  exit
end
fname = ARGV[0]
oname = fname.gsub(/\.xml$/,'.nodelink.html') # }}} 

s = if debug
   `xsltproc #{File.expand_path(File.dirname(__FILE__) + '/helpers/nodelink_orga.xsl')} #{fname} | dot -Tsvg | xsltproc #{File.expand_path(File.dirname(__FILE__) + '/helpers/nodelink_tran.xsl')} -`
else  
   `xsltproc #{File.expand_path(File.dirname(__FILE__) + '/helpers/nodelink_orga.xsl')} #{fname} | dot -Tsvg | xsltproc #{File.expand_path(File.dirname(__FILE__) + '/helpers/nodelink_tran.xsl')} - 2>/dev/null`
end

h = HTML.new('NodeLink')
h.add_css '.highlight path', <<-end
  stroke: #a40000;
end
h.add_css '.highlight polygon', <<-end
  stroke: #a40000;
end
h.add_css '.entity', <<-end
  cursor: pointer;
end
h.add_js <<end
  function over_entity(target) {
    var tname = $(target).attr('id').replace(/entity_[^_]*_/,'');
    var tnamer = new RegExp(tname);
    $('.edge').each(function(e,f){
      if ($(f).attr('id').match(tnamer)) {
        var pname = $(f).attr('id').replace(/edge_[^_]*_/,'');
            pname = pname.replace(/_(a|b)$/,'');
            pname = pname.split('--');
        $('.unit, .role, .subject').each(function(g,h){
          if (
               $(h).attr('id') == 'entity_unit_' + pname[0] || 
               $(h).attr('id') == 'entity_role_' + pname[0] || 
               $(h).attr('id') == 'entity_subject_' + pname[0] ||
               $(h).attr('id') == 'entity_unit_' + pname[1] || 
               $(h).attr('id') == 'entity_role_' + pname[1] || 
               $(h).attr('id') == 'entity_subject_' + pname[1]
             ) {
            $(h).addClass('highlight');
          }  
        });
        $(f).addClass('highlight');
      }
    });  
  }
  function out_entity(target) {
    $('.highlight').each(function(e,f){
      $(f).removeClass('highlight');
    });  
  }
end

c = h.add_tag 'div', :class => "tabbed rest" do
  h.add_tag 'table', :class => "tabbar" do
    h.add_tag 'tbody' do
      h.add_tag 'tr' do
        h.add_tag 'td', :class => 'tabbefore'
        h.add_tag 'td', :class => 'tab', :id => 'tabgraph' do
          h.add_tag('h1'){ 'NodeLink' }
        end
        h.add_tag 'td', :class => 'tabbehind'
      end
    end
  end
  h.add_tag 'div', :class => "tabbelow" do
    s
  end
end  

h.add c
File.open(oname,'w'){|f|f.write h.dump}
