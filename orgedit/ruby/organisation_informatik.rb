#!/usr/bin/ruby
# encoding: UTF-8
### All code in this file is provided under the LGPL license. Please read the file COPYING.
require 'rubygems'
require 'xml/smart'
require 'net/http'
require 'pp'

stellungen = [
  [ "Beamtin", "Regular", "Staff" ],
  [ "Arbeitnehmerin", "Regular", "Staff" ],
  [ "Angestellte", "Regular", "Staff" ],
  [ "Angestellter", "Regular", "Staff" ],
  [ "Assistenzprofessor", "Ass.Prof." ],
  [ "Projektmitarbeiter", "Project", "Assistant" ],
  [ "Außerordentlicher Universitätsprofessor", "Univ.Prof." ],
  [ "Außerordentliche Universitätsprofessorin", "Univ.Prof." ],
  [ "Universitätsassistent", "Regular", "Assistant" ],
  [ "Assoziierter Professor", "Univ.Prof." ],
  [ "Universitätsprofessorin", "Univ.Prof." ],
  [ "Arbeitnehmer", "Regular", "Staff" ],
  [ "Kollegassistent", "Regular", "Staff" ],
  [ "Universitätsassistentin", "Regular", "Assistant" ],
  [ "Projektmitarbeiterin", "Project", "Assistant" ],
  [ "Universitätsprofessor", "Univ.Prof." ],
  [ "Außerord. Universitätsprofessor", "Univ.Prof." ],
  [ "Beamter", "Regular", "Staff" ],
  [ "Lektor", "Teaching" ],
  [ "Lektorin", "Teaching" ],
  [ "Senior Lecturer", "Senior Lecturer"]
]

additionalsubjects = {
  'kriglss9' => ["Kriglstein Simone", {"A791"=>["Projektmitarbeiter"]}],
  'manglej6' => ["Mangler Juergen", {"A791"=>["Projektmitarbeiter"]}],
  'sahannr6' => ["Sahann Raphael", {"A781"=>["Angestellter"]}]
}  

ausnahmen = [
  ["Ernst", "Buchberger"],
  ["Georg", "Dorffner"],
  ["Georg", "Duftschmid"],
  ["Harald", "Trost"],
  ["Johann", "Hainfellner"],
  ["Klaus-Peter", "Adlassnig"],
  ["Michael", "Trimmel"],
  ["Rudolf", "Karch"],
  ["Walter", "Gall"],
  ["Werner", "Horn"],
  ["Wolfgang", "Dorda"],
  ["Wolfgang", "Schreiner"]
]

# stellungen = [
#   [ "2172", "Regular", "Staff"],
#   [ "2232", "Regular", "Staff"],
#   [ "2243", "Univ.Prof."],
#   [ "2253", "Univ.Prof."],
#   [ "2293", "Ass.Prof."],
#   [ "2762", "Project", "Staff"],
#   [ "2782", "Project", "Prae.Doc."],
#   [ "2863", "Regular", "Staff"],
#   [ "3072", "Regular", "Prae.Doc."],
#   [ "3142", "Regular", "Post.Doc."],
#   [ "3922", "Regular", "Staff"],
#   [ "3932", "Regular", "Staff"],
#   [ "3942", "Regular", "Staff"],
#   [ "3952", "Regular", "Staff"],
#   [ "4062", "Project", "Staff"],
#   [ "4102", "Univ.Prof."],
#   [ "4172", "Project", "Prae.Doc."],
#   [ "4182", "Project", "Prae.Doc."],
#   [ "4252", "Senior Lecturer"],
#   [ "4322", "Regular", "Post.Doc."],
#   [ "4342", "Ass.Prof."],
#   [ "4552", "Univ.Prof."],
#   [ "4562", "Univ.Prof."],
#   [ "4262", "Regular", "Prae.Doc."],
#   [ "4292", "Regular", "Prae.Doc."]
# ]

gruppen = [
  [ 'A780', 'Dekanat Informatik'],
  [ 'A781', 'Studienservicecenter Informatik'],
  [ 'A782', 'Educational Technologies'],
  [ 'A783', 'Theory and Applications of Algorithms'],
  [ 'A784', 'Scientific Computing'],
  [ 'A785', 'Software Architectures'],
  [ 'A786', 'Future Communication'],
  [ 'A787', 'Entertainment Computing'],
  [ 'A788', 'Multimedia Information Systems'],
  [ 'A789', 'Knowledge Engineering'],
  [ 'A790', 'Visualization and Data Analysis'],
  [ 'A791', 'Workflow Systems and Technology'],
  [ 'A792', 'Data Analytics and Computing'],
  [ 'A793', 'Bioinformatics and Computational Biology'],
  [ 'A794', 'Cooperative Systems']
]

fname = '/tmp/faculty.xml'
if !File.exists?(fname) || File.mtime(fname)<Time.now-3600*24
  File.open(fname,'w') do |f|
    xml = Net::HTTP.get(URI.parse('http://online.univie.ac.at/pers?kapitel=39&match=exact&format=xml'))
    f.write xml.gsub(/(<\?xml.*?\?>)/,"\\1\n<!DOCTYPE xhtmlentities PUBLIC '-//W3C//ENTITIES XHTML Character Entities 1.0//EN' '/xhtml11.ent'>")
  end
end

m = Time.now.month 
s = (m >= 10 || m <= 2) ? 'W' : 'S'
y = (m <= 2) ? Time.now.year - 1 : Time.now.year
sq = s + y.to_s

xstell = []
subjects = additionalsubjects
stellnums = stellungen.map{|s|s[0]}
XML::Smart.open('/tmp/faculty.xml') do |doc|
  gruppen.each do |k,v|
    doc.find("/personenverzeichnis/person[@aktiv='ja' and */@inum='#{k}  ']").each do |p|
      if p.attributes['email'] != '' && p.attributes['username'] != ''
        stells = []
        p.find("*[@inum='#{k}  ']/@stellungen").each{ |s| stells += s.to_s.split(',') }
        xstell << stells.flatten
        stells.delete_if do |stell|
          !stellnums.include?(stell)
        end
        if stells.any? && !ausnahmen.find{|e| e[0] == p.attributes['vorname'] && e[1] == p.attributes['zuname']}
          # subjects[p.attributes['username']] ||= [p.attributes['vorname'].gsub(/[A-Z]/,'X').gsub(/[^X -]/,'x') + " " + p.attributes['zuname'].gsub(/[A-Z]/,'X').gsub(/[^X -]/,'x'),{}]
          subjects[p.attributes['username']] ||= [p.attributes['zuname'] + " " + p.attributes['vorname'],{}]
          subjects[p.attributes['username']][1][k] ||= []
          subjects[p.attributes['username']][1][k] += stells
          if p.find("boolean(lv/#{sq})")
            unless subjects[p.attributes['username']][1][k].include?('Lektor') || subjects[p.attributes['username']][1][k].include?('Lektorin')
              subjects[p.attributes['username']][1][k] += ['Lektor']
            end  
            p subjects[p.attributes['username']][1][k]
          end
        end
      end  
    end
  end

  XML::Smart.modify('organisation_informatik.xml') do |org|
    org.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
    org.find('/o:organisation/o:subjects/o:subject').delete_all!
    s = org.find('/o:organisation/o:subjects').first
    subjects.each do |k,u|
      next if u[1].values.flatten.uniq == ['Lektor'] || u[1].values.flatten.uniq == ['Lektorin']
      n = s.add('subject',:id=>u[0], :uid => k)
      u[1].each do |inum,e|
        e.each do |stell|
          stellungen.find{|x|x[0] == stell}[1..-1].each do |st|
            n.add('relation', :unit => gruppen.find{|x|x[0] == inum}[1], :role => st)
          end  
        end
      end
    end
  end
end