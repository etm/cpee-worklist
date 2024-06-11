# This file is part of CPEE-WORKLIST
#
# CPEE-WORKLIST is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# CPEE-WORKLIST is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with CPEE-WORKLIST (file LICENSE in the main directory). If not, see
# <http://www.gnu.org/licenses/>.


module CPEE
  module Worklist

    module User
      def self::ok?(opts,task,user)
        fname = File.join(opts[:top],'orgmodels',Riddl::Protocols::Utils::escape(task['orgmodel']))
        orgmodel = XML::Smart.open_unprotected(fname)
        orgmodel.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
        subjects = orgmodel.find('/o:organisation/o:subjects/o:subject')
        unit = task['unit']
        role = task['role']
        if (unit=='*')
          if (role=='*')
            subjects.each{|s| return true if s.attributes['uid']==user}
          else
            orgmodel.find("/o:organisation/o:subjects/o:subject[o:relation/@role='#{role}']").each do |s|
              return true if user==s.attributes['uid']
            end
          end
        else
          if (role=='*')
            orgmodel.find("/o:organisation/o:subjects/o:subject[o:relation/@unit='#{unit}']").each do |s|
              return true if user==s.attributes['uid']
            end
          else
            orgmodel.find("/o:organisation/o:subjects/o:subject[o:relation/@unit='#{unit}' and o:relation/@role='#{role}']").each do |s|
              return true if user==s.attributes['uid']
            end
          end
        end
        false
      end

      def self::info(opts,task,user)
        fname = File.join(opts[:top],'orgmodels',Riddl::Protocols::Utils::escape(task['orgmodel']))
        orgmodel = XML::Smart.open_unprotected(fname)
        orgmodel.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
        user = orgmodel.find("/o:organisation/o:subjects/o:subject[@uid='#{user}']/o:relation")
        {}.tap{ |t| user.map{|u| (t[u.attributes['unit']]||=[]) <<  u.attributes['role']}}
      end
    end

  end
end
