<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
<xsl:output method="html" indent="yes"/>
<!-- Main page template -->
<xsl:template match="/">
<html>
  <head>
    <title><xsl:apply-templates select="*" mode="title" /></title>
    <style type="text/css">
body { font-family: arial, helvetica, sans-serif; margin: 0 }
.l { text-align: left }
.r { text-align: right }
.c { text-align: center }
h3 { background-color: #ccf; color: #000; padding: 5px; margin: 0 0 5px }
table { width: 100%; margin: auto }
table th { background-color: #ddd }
table td { background-color: #eee }
ul { margin-top: 0 ; margin-bottom: 0 }
    </style>
  </head>
  <body>
    <xsl:apply-templates select="*" />
  </body>
</html>
</xsl:template>


<xsl:template match="DASDSN"      mode="title">DSN</xsl:template>
<xsl:template match="SOURCES"     mode="title">Sources</xsl:template>
<xsl:template match="DASTYPES"    mode="title">Feature types</xsl:template>
<xsl:template match="DASGFF"      mode="title">Features</xsl:template>
<xsl:template match="DASSTYLE"    mode="title">StyleSheet</xsl:template>
<xsl:template match="DASEP"       mode="title">EntryPoints</xsl:template>
<xsl:template match="DASSEQUENCE" mode="title">Sequence</xsl:template>
<xsl:template match="DASDNA"      mode="title">DNA Sequence</xsl:template>

<!-- TABLES.... -->
<xsl:template match="DASDSN">
<h3>DAS sources available</h3>
<table>
<thead>
  <tr>
    <th>#</th>
    <th>ID</th>
    <th>Version</th>
    <th>Map Master</th>
    <th width="50%">Notes</th>
  </tr>
</thead>
<tbody>
  <xsl:apply-templates select="DSN" />
</tbody>
</table>
</xsl:template>

<xsl:template match="SOURCES">
<h3>DAS sources available</h3>
<table>
<thead>
  <tr>
    <th>#</th>
    <th>URI</th>
    <th>Title</th>
    <th>Docs</th>
    <th>Test range</th>
    <th>Taxon ID</th>
    <th>Maintainer</th>
    <th>Capabilities</th>
    <th>Description</th>
  </tr>
</thead>
<tbody>
  <xsl:apply-templates select="SOURCE">
    <xsl:sort select="substring-before(@title,'.')" />
    <xsl:sort select="@uri" />
  </xsl:apply-templates>
</tbody>
</table>
</xsl:template>

<xsl:template match="DASTYPES">
  <xsl:apply-templates select="GFF" mode="type" />
</xsl:template>

<xsl:template match="DASGFF">
  <xsl:apply-templates select="GFF" mode="gff" />
</xsl:template>

<xsl:template match="DASSTYLE">
  <xsl:apply-templates select="STYLESHEET" />
</xsl:template>

<xsl:template match="DASEP">
  <xsl:apply-templates select="ENTRY_POINTS" />
</xsl:template>

<xsl:template match="DASSEQUENCE">
  <xsl:apply-templates select="SEQUENCE" mode="seq" />
</xsl:template>

<xsl:template match="DASDNA">
  <xsl:apply-templates select="SEQUENCE" mode="dna" />
</xsl:template>

<!-- DSN... -->
<xsl:template match="DSN">
  <tr>
    <td class="r"><xsl:value-of select="position()"/></td>
    <td class="l"><xsl:value-of select="SOURCE/@id"/></td>
    <td class="c"><xsl:value-of select="SOURCE/@version"/></td>
    <td class="l"><xsl:value-of select="MAPMASTER"/></td>
    <td class="l"><xsl:value-of select="DESCRIPTION" /></td>
  </tr>
</xsl:template>

<!-- Sources -->
<xsl:template match="SOURCE">
  <tr>
    <td class="r"><xsl:value-of select="position()"/></td>
    <td class="l"><xsl:value-of select="@uri"/></td>
    <td class="l"><xsl:value-of select="@title"/></td>
    <td class="c">
      <xsl:choose>
        <xsl:when test="@doc_href">
          <xsl:element name="a">
            <xsl:attribute name="href"><xsl:value-of select="@doc_href" /></xsl:attribute>
            Docs
          </xsl:element>
        </xsl:when>
        <xsl:otherwise>-</xsl:otherwise>
      </xsl:choose>
    </td>
    <td class="l"><xsl:value-of select="VERSION/COORDINATES/@test_range"/></td>
    <td class="c"><xsl:value-of select="VERSION/COORDINATES/@taxid" /></td>
    <td class="l"><ul>
      <xsl:apply-templates select="VERSION/CAPABILITY" />
    </ul></td>
    <td class="l"><xsl:value-of select="@description" /></td>
  </tr>
</xsl:template>

<xsl:template match="VERSION/CAPABILITY">
  <xsl:variable name="protocol" select="substring-before(@type,':')" />
  <xsl:variable name="function" select="substring-after( @type,':')" />
      <li>
  <xsl:choose>
    <xsl:when test="($function='entry_points') or ($function='stylesheet')">
      <xsl:element name="a">
        <xsl:attribute name="href">/das/<xsl:value-of select="../../@title" />/<xsl:value-of select="$function" /></xsl:attribute>
        <xsl:value-of select="@type" />
      </xsl:element>
    </xsl:when>
    <xsl:otherwise>
      <xsl:element name="a">
        <xsl:attribute name="href">/das/<xsl:value-of select="../../@title" />/<xsl:value-of select="$function" />?segment=<xsl:value-of select="../COORDINATES/@test_range" /></xsl:attribute>
        <xsl:value-of select="@type" />
      </xsl:element>
    </xsl:otherwise>
  </xsl:choose>
      </li>
</xsl:template>

<!-- Types -->

<xsl:template match="GFF" mode="type">
  <h3>Das types from: <xsl:value-of select="@href"/></h3>
  <table><tbody>
    <xsl:apply-templates select="SEGMENT|ERRORSEGMENT|UNKNOWNSEGMENT" mode="type">
      <xsl:sort select="@id" />
    </xsl:apply-templates>
  </tbody></table>
</xsl:template>

<xsl:template match="UNKNOWNSEGMENT" mode="type">
  <tr><th class="l" colspan="5">Unknown Segment: <xsl:value-of select="@id" />:<xsl:value-of select="@start" />-<xsl:value-of select="@stop" /></th></tr>
</xsl:template>
<xsl:template match="ERRORSEGMENT" mode="type">
  <tr><th class="l" colspan="5">Error Segment (region outside range): <xsl:value-of select="@id" />:<xsl:value-of select="@start" />-<xsl:value-of select="@stop" /></th></tr>
</xsl:template>
<xsl:template match="SEGMENT" mode="type">
  <tr><th class="l" colspan="5">Segment: <xsl:value-of select="@id" />:<xsl:value-of select="@start" />-<xsl:value-of select="@stop" /></th></tr>
  <xsl:choose>
    <xsl:when test="TYPE">
    <tr>
      <th>#</th>
      <th>Category</th>
      <th>Type</th>
      <th>Method</th>
      <th>Count</th>
    </tr>
    </xsl:when>
    <xsl:otherwise>
    <tr><td class="c" colspan="5">No features on this segment</td></tr>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:apply-templates select="TYPE" mode="gff">
    <xsl:sort select="@category" />
    <xsl:sort select="@id" />
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="TYPE" mode="gff">
  <tr>
    <td class="r"><xsl:value-of select="position()" /></td>
    <td class="c"><xsl:value-of select="@category" /></td>
    <td class="c"><xsl:value-of select="@id" /></td>
    <td class="c"><xsl:value-of select="@method" /></td>
    <td class="r"><xsl:value-of select="." /></td>
  </tr>
</xsl:template>

<!-- GFF -->
<xsl:template match="GFF" mode="gff">
  <h3>Features from: <xsl:value-of select="@href"/></h3>
  <table>
  <xsl:apply-templates select="SEGMENT|ERRORSEGMENT|UNKNOWNSEGMENT" mode="gff">
    <xsl:sort select="@id" />
  </xsl:apply-templates>
  </table>
</xsl:template>

<xsl:template match="UNKNOWNSEGMENT" mode="gff">
  <tr><th class="l" colspan="11"> Unknown Segment: <xsl:value-of select="@id" />:<xsl:value-of select="@start" />-<xsl:value-of select="@stop" /></th></tr>
</xsl:template>
<xsl:template match="ERRORSEGMENT" mode="gff">
  <tr><th class="l" colspan="11">Error Segment (region outside range): <xsl:value-of select="@id" />:<xsl:value-of select="@start" />-<xsl:value-of select="@stop" /></th></tr>
</xsl:template>

<xsl:template match="SEGMENT" mode="gff">
  <tr><th class="l" colspan="11">Segment: <xsl:value-of select="@id" />:<xsl:value-of select="@start" />-<xsl:value-of select="@stop" /></th></tr>
  <xsl:choose>
    <xsl:when test="FEATURE">
  <tr>
    <th>#</th>
    <th>Label<br />(Grouping)</th>
    <th>Type<br />Category</th>
    <th>Method</th>
    <th>Start</th>
    <th>End</th>
    <th>Orientation</th>
    <th>Score</th>
    <th>Target</th>
    <th>Links</th>
    <th>Notes</th>
  </tr>
    </xsl:when>
    <xsl:otherwise>
    <tr><td class="c" colspan="11">No features on this segment</td></tr>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:apply-templates select="FEATURE">
    <xsl:sort select="TYPE/@id" />
    <xsl:sort select="START" data-type="number" />
  </xsl:apply-templates>
</xsl:template>

<xsl:template match="FEATURE">
  <xsl:param name="type" />
  <xsl:variable name="base_URL" select="substring-before(../../@href,'/features')" />
  <tr>
    <td class="r"><xsl:value-of select="position()" /></td>
    <td class="l"><ul>
      <li><xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:value-of select="$base_URL" />/features?feature_id=<xsl:value-of select="@id" />
        </xsl:attribute><xsl:choose>
        <xsl:when test="@label">
          <xsl:value-of select="@label" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="@id" />
        </xsl:otherwise>
        </xsl:choose>
      </xsl:element></li>
      <xsl:apply-templates select="GROUP" mode="gff">
        <xsl:with-param name="base_URL" select="$base_URL" />
        <xsl:sort select="@id" />
      </xsl:apply-templates>
    </ul></td>
    <td class="c"><xsl:value-of select="TYPE/@id"       /><xsl:value-of select="TYPE"       /><br /><xsl:value-of select="TYPE/@category" /></td>
    <td class="c"><xsl:value-of select="METHOD/@id"     /><xsl:value-of select="METHOD"     /></td>
    <td class="r"><xsl:value-of select="START"      /></td>
    <td class="r"><xsl:value-of select="END"        /></td>
    <td class="c"><xsl:value-of select="ORIENTATION"/></td>
    <td class="c"><xsl:value-of select="SCORE"      /></td>
    <td class="c"><xsl:choose>
      <xsl:when test="TARGET">
        <xsl:value-of select="TARGET/@id" /><br />
        <xsl:value-of select="TARGET/@start" />-<xsl:value-of select="TARGET/@stop" />
      </xsl:when>
      <xsl:otherwise>
        -
      </xsl:otherwise>
    </xsl:choose></td>
    <td class="l"><ul>
    <xsl:if test="TYPE/@reference='yes'">
      <xsl:if test="TYPE/@subparts='yes'">
        <li><xsl:element name="a">
        <xsl:attribute name="href"><xsl:value-of select="$base_URL" />/features?segment=<xsl:value-of select="@id" />:<xsl:value-of select="TARGET/@start" />,<xsl:value-of select="TARGET/@stop" /></xsl:attribute>
          <em>DAS</em> Assembly
        </xsl:element></li>
      </xsl:if>
      <li><xsl:element name="a">
        <xsl:attribute name="href"><xsl:value-of select="$base_URL" />/sequence?segment=<xsl:value-of select="@id" /></xsl:attribute>
          <em>DAS</em> Sequence
      </xsl:element></li>
    </xsl:if>
    <xsl:apply-templates select="LINK"/>
    <xsl:apply-templates select="GROUP/LINK"/>
    </ul></td>
    <td class="l">
      <xsl:if test="(NOTE) or (GROUP/NOTE)"><ul>
        <xsl:apply-templates select="NOTE"/>
        <xsl:apply-templates select="GROUP/NOTE"/>
      </ul></xsl:if></td>
  </tr>
</xsl:template>

<xsl:template match="GROUP" mode="gff">
  <xsl:param name="base_URL" />
  <li><xsl:element name="a">
    <xsl:attribute name="href">
      <xsl:value-of select="$base_URL" />/features?group_id=<xsl:value-of select="@id" />
    </xsl:attribute><xsl:choose>
    <xsl:when test="@label">
      <xsl:value-of select="@label" />
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="@id" />
    </xsl:otherwise>
    </xsl:choose>
  </xsl:element></li>
</xsl:template>


<xsl:template match="LINK">
  <xsl:choose>
    <xsl:when test="(@href) and (@href!='')">
      <li><xsl:element name="a">
        <xsl:attribute name="href"><xsl:value-of select="@href"/></xsl:attribute>
        <xsl:value-of select="."/>
      </xsl:element></li>
    </xsl:when>
    <xsl:otherwise>
      <li><span class="nb"><xsl:value-of select="." /></span></li>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="NOTE">
  <li><small><xsl:value-of select="."/></small></li>
</xsl:template>


<!-- STYLESHEETS -->
<xsl:template match="STYLESHEET">
<h3>Feature styles...</h3>
<table>
<tr>
  <th>#</th>
  <th>Category</th>
  <th>Type</th>
  <th>Glyph</th>
</tr>
  <xsl:apply-templates select="CATEGORY/TYPE" mode="ss">
    <xsl:sort select="../@id" />
    <xsl:sort select="@id" />
  </xsl:apply-templates>
</table>
</xsl:template>

<xsl:template match="CATEGORY/TYPE" mode="ss">
  <tr>
    <xsl:element name="td">
      <xsl:attribute name="class">r</xsl:attribute>
      <xsl:attribute name="rowspan"><xsl:value-of select="count(GLYPH/*)" /></xsl:attribute>
      <xsl:value-of select="position()" />
    </xsl:element>
    <xsl:element name="td">
      <xsl:attribute name="class">c</xsl:attribute>
      <xsl:attribute name="rowspan"><xsl:value-of select="count(GLYPH/*)" /></xsl:attribute>
      <xsl:value-of select="../@id" />
    </xsl:element>
    <xsl:element name="td">
      <xsl:attribute name="class">c</xsl:attribute>
      <xsl:attribute name="rowspan"><xsl:value-of select="count(GLYPH/*)" /></xsl:attribute>
      <xsl:value-of select="@id" />
    </xsl:element>
    <xsl:apply-templates select="GLYPH[position()=1]/*[position()=1]" mode="ss" />
  </tr>
  <xsl:apply-templates select="GLYPH[position()=1]/*[position()!=1]" mode="ss-tr"></xsl:apply-templates>
  <xsl:apply-templates select="GLYPH[position()!=1]/*" mode="ss-tr"></xsl:apply-templates>
</xsl:template>

<xsl:template match="GLYPH/*" mode="ss-tr">
  <tr>
    <xsl:apply-templates select="." mode="ss"/>
  </tr>
</xsl:template>

<xsl:template match="GLYPH/*" mode="ss">
  <td class="l">
    <strong><xsl:value-of select="name(.)" />: </strong>
    <xsl:apply-templates select="." mode="ss-attr" />
  </td>
</xsl:template>

<xsl:template match="*" mode="ss-attr">
  <xsl:for-each select="*">
    <xsl:sort select="name(.)" />
    <xsl:value-of select="name(.)" /> = <xsl:value-of select="." />;
  </xsl:for-each>
</xsl:template>

<!-- Entrypoints -->

<xsl:template match="ENTRY_POINTS">
<h3>Entry points</h3>
<table>
<thead>
  <tr>
    <th>#</th>
    <th>Name</th>
    <th>Type</th>
    <th>Start</th>
    <th>End</th>
    <th>Orientation</th>
    <th>-</th>
  </tr>
</thead>
<tbody>
  <xsl:apply-templates select="SEGMENT" mode="ep">
    <xsl:sort select="@stop" data-type="number" order="descending"/>
  </xsl:apply-templates>
</tbody>
</table>
</xsl:template>
<xsl:template match="SEGMENT" mode="ep">
  <xsl:variable name="base" select="substring-before( ../@href, '/entry_points' )" />
  <tr>
    <td class="r"><xsl:value-of select="position()"   /></td>
    <td class="l"><xsl:value-of select="@id"          /></td>
    <td class="l"><xsl:value-of select="@type"        /></td>
    <td class="r"><xsl:value-of select="@start"       /></td>
    <td class="r"><xsl:value-of select="@stop"        /></td>
    <td class="c"><xsl:value-of select="@orientation" /></td>
    <td class="c"><xsl:choose>
      <xsl:when test="@subparts">
        <xsl:element name="a">
          <xsl:attribute name="href">
            <xsl:value-of select="$base" />/features?segment=<xsl:value-of select="@id" />:<xsl:value-of select="@start" />,<xsl:value-of select="@stop" />
          </xsl:attribute>
          Elements
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="a">
          <xsl:attribute name="href">
            <xsl:value-of select="$base" />/features?segment=<xsl:value-of select="@id" />:<xsl:value-of select="@start" />,<xsl:value-of select="@stop" />
          </xsl:attribute>
          XXX
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
    </td>
  </tr>
</xsl:template>

<!-- Sequence -->
<xsl:template match="SEQUENCE" mode="dna">
<h3>Segment: <xsl:value-of select="@id" />:<xsl:value-of select="@start" />-<xsl:value-of select="@stop" /></h3>
<pre>
  <xsl:call-template name="seq">
    <xsl:with-param name="dna"><xsl:value-of select="translate(normalize-space(DNA),' ','')" /></xsl:with-param>
    <xsl:with-param name="pos"><xsl:value-of select="@start" /></xsl:with-param>
  </xsl:call-template>
</pre>
</xsl:template>
<xsl:template match="SEQUENCE" mode="seq">
<h3>Segment: <xsl:value-of select="@id" />:<xsl:value-of select="@start" />-<xsl:value-of select="@stop" /></h3>
<pre>
  <xsl:call-template name="seq">
    <xsl:with-param name="dna"><xsl:value-of select="translate(normalize-space(.),' ','')" /></xsl:with-param>
    <xsl:with-param name="pos"><xsl:value-of select="@start" /></xsl:with-param>
  </xsl:call-template>
</pre>
</xsl:template>
<xsl:template name="seq">
  <xsl:param name="dna" />
  <xsl:param name="pos" />
  <xsl:choose>
    <xsl:when test="string-length($dna) &gt; 6000000">
      <xsl:call-template name="seq">
        <xsl:with-param name="dna" select="substring($dna,1,6000000)" />
        <xsl:with-param name="pos" select="$pos" />
      </xsl:call-template>
      <xsl:call-template name="seq">
        <xsl:with-param name="dna" select="substring($dna,6000001)" />
        <xsl:with-param name="pos" select="$pos + 6000000" />
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="string-length($dna) &gt; 6000">
      <xsl:call-template name="seq">
        <xsl:with-param name="dna" select="substring($dna,1,6000)" />
        <xsl:with-param name="pos" select="$pos" />
      </xsl:call-template>
      <xsl:call-template name="seq">
        <xsl:with-param name="dna" select="substring($dna,6001)" />
        <xsl:with-param name="pos" select="$pos + 6000" />
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="string-length($dna) &gt; 60">
      <xsl:call-template name="seq">
        <xsl:with-param name="dna" select="substring($dna,1,60)" />
        <xsl:with-param name="pos" select="$pos" />
      </xsl:call-template>
      <xsl:call-template name="seq">
        <xsl:with-param name="dna" select="substring($dna,61)" />
        <xsl:with-param name="pos" select="$pos + 60" />
      </xsl:call-template>
    </xsl:when>
    <xsl:when test="$dna != ''">
      <xsl:variable name="rpos"      select="$pos + string-length($dna) -1" />
      <xsl:value-of select="concat( substring(concat('          ',$pos),string-length(string($pos))), ' ')" />
      <xsl:value-of select="substring(concat( $dna,'                                                                                                    '),1,60)" />
      <xsl:value-of select="substring(concat('           ',$rpos),string-length(string($rpos)))" />
    <br />
    </xsl:when>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>


