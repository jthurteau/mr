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

#################################################################
  private
#################################################################



end