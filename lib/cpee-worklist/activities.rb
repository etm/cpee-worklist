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
    class Activities < Array
      def initialize(opts)
        super()
        @opts = opts
      end

      def unserialize
        self.clear.replace JSON.parse!(File.read(File.join(@opts[:top],'activities.sav'))) rescue []
      end

      def  serialize
        Thread.new do
          File.write File.join(@opts[:top],'activities.sav'), JSON.pretty_generate(self)
        end
      end
    end
  end
end
