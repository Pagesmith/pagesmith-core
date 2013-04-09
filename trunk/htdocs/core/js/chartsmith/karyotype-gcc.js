/*jsl:ignoreall*/var cs_karyotype_defaults={chromosomes:[],width:0.2,karyo_set:[],colours:{gneg:"#fff",gpos66:"#808080",gpos50:"#999",gpos75:"#666",gpos100:"#000",acen:"#666",gvar:"#ddd",stalk:"#666",tip:"#666",gpos33:"#404040",gpos25:"#ccc"},edge_colour:"#000",empty_colour:"#eee",max_len:0,valid_x:{}};Raphael.fn.cs_karyotype_render=function(){var h,e,b,c,a,d,f,g,i,j;if(this.cs_karyotype.chromosomes.length){h=this.set();for(e=this.cs_karyotype.chromosomes.length;e;){e--;b=this.cs_karyotype.width;c=this.cs_karyotype.chromosomes[e];a=c.name;d=parseInt(c.len,10);c=c.bands;f=0;if("undefined"!==typeof c)for(g=c.length;g;){g--;i=parseInt(c[g].start,10);switch(c[g].stain){case "acen":d=f?[{val:a,off:-b},i,a,d,{val:a,off:b},i]:[{val:a,off:-b},d,a,i,{val:a,off:b},d];f=1-f;break;case "stalk":d=[{val:a,off:-b/2},i,{val:a,off:-b/2},d,{val:a,off:b/2},d,{val:a,off:b/2},i];break;default:d=[{val:a,off:-b},i,{val:a,off:-b},d,{val:a,off:b},d,{val:a,off:b},i]}j=this.cs_karyotype.colours[c[g].stain];h.push(this.cs_add_poly({pts:d,stroke:this.cs_karyotype.edge_colour,opts:{"stroke-width":0.5},fill:j}));d=i-1}1<d&&h.push(this.cs_add_poly({pts:[{val:a,off:-b},1,{val:a,off:-b},d,{val:a,off:b},d,{val:a,off:b},1],stroke:this.cs_karyotype.edge_colour,opts:{"stroke-width":0.5},fill:this.cs_karyotype.empty_colour}))}this.cs_karyotype.karyo_set=h}else this.text(100,50,"This species has no karyotype")};Raphael.fn.cs_karyotype_draw_features=function(h,e){var b=[],c=0,a=0,d,f,g;for(d=h.length;d;)d--,f=h[d],this.cs_karyotype.valid_x[f.chr]?(c++,g=parseInt(f.strand,10),b.push({x:{val:f.chr,off:0.25*g},y:(parseInt(f.start,10)+parseInt(f.end,10))/2,shape:0>g?">":"<",label:f.label,value:f.id})):a++;return{pts:this.cs_add_points(b,e),drawn:c,not_drawn:a}};Raphael.fn.cs_karyotype_init=function(h,e){var b=[],c=0,a,d;this.cs_karyotype=cs_karyotype_defaults;this.cs_karyotype.chromosomes=e;this.cs_karyotype.max_len=0;this.cs_karyotype.valid_x=[];if(e.length){for(a=e.length;a;)a--,this.cs_karyotype.valid_x[e[a].name]=1,b.unshift(e[a].name),d=parseInt(e[a].len,10),d>c&&(c=d);if(0<c){a=Math.pow(10,Math.floor(Math.log(c)/Math.LN10));5>c/a&&(a*=0.5);a={minvalue:-a/10,maxvalue:c+a/10,dir:"+",scaling:"linear",line:"#ccc",label:"Basepairs",axis_pos:"left",major:a,minor:5,label_scale:1E6,label_dp:0,label_suffix:"Mb"};if(5E6>c)a.label_dp=1;if(5E5>c)a.label_dp=0,a.label_scale=1E3,a.label_suffix="Kb";if(5E4>c)a.label_dp=1;if(1E4>c)a.label_dp=0,a.label_scale=1,a.label_suffix="";b={object:h,margins:{top:10,right:10,left:50,bottom:40},xaxis:{minvalue:0,maxvalue:1,scaling:"discrete",line:"#ccc",values:b,label:"Chromosome",axis_pos:"below"},yaxis:a};this.cs_init(b)}this.cs_karyotype.max_len=c}};