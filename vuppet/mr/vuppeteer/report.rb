## 
# Encapsulates report management for mr
#

module Report
  extend self

  @report_matrix = {}

  def self.push(facet, field, prop)
    @report_matrix[facet] = {} if !@report_matrix[facet]
    @report_matrix[facet][field] = [] if !@report_matrix[facet][field]
    @report_matrix[facet][field].push(prop)
  end

  def self.pop(facet, format = [:header, :extra_line])
    format = MrUtils::enforce_enumerable(format)
    head = format.include?(:header) ? "Report for \"#{facet}\": " : ''
    body = @report_matrix.has_key?(facet) ? @report_matrix[facet].to_s : '[] (none)'
    footer = format.include?(:extra_line) ? "\n" : ''
    return "#{head}#{body}#{footer}"
    @report_matrix.delete(facet)
  end

#################################################################
  private
#################################################################



end