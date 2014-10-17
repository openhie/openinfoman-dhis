<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:svs="urn:ihe:iti:svs:2008"
  xmlns="http://dhis2.org/schema/dxf/2.0"
  exclude-result-prefixes="xs"
  version="1.0">
  
  <xsl:output method="xml" encoding="UTF-8" indent="yes" />
  
  <!-- valid values: Monthly, Quarterly, SixMonthly, Yearly ... -->
  <xsl:param name="periodType">Monthly</xsl:param>
  
  <xsl:template match="/">
    <metaData>
      
      <dataElements>
        <xsl:apply-templates select="//svs:Concept" mode="dataelements"/>  
      </dataElements>
      
      <dataSets>
        <xsl:apply-templates select="svs:ValueSet"/>
      </dataSets>
    </metaData>    
  </xsl:template>
  
  <xsl:template match="svs:ValueSet">
    <xsl:variable name="shortName" select="substring(@displayName,1,25)"/>
    <dataSet code='{@id}' name='{@displayName}' shortName='{$shortName}'>
      <periodType><xsl:value-of select="$periodType"/></periodType>
      <dataElements>
        <xsl:apply-templates select="//svs:Concept" mode="dataset" />
      </dataElements>
    </dataSet>
  </xsl:template>
  
  <xsl:template match="svs:Concept" mode="dataelements">
    <xsl:variable name="shortName" select="substring(@displayName,1,25)"/>
    <dataElement name='{@displayName}' shortName='{$shortName}' code='{@code}' >
      <active>true</active>
      <domainType>aggregate</domainType>
      <type>int</type>
      <numberType>number</numberType>
      <aggregationOperator>average</aggregationOperator>
      <zeroIsSignificant>false</zeroIsSignificant>
      <legendSet/>
    </dataElement>
  </xsl:template>

  <xsl:template match="svs:Concept" mode="dataset" >
    <dataElement name='{@displayName}' code='{@code}' />
  </xsl:template>
      
</xsl:stylesheet>