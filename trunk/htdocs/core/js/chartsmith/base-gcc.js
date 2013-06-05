/*jsl:ignoreall*/var Chartsmith_Collector={},cs_defaults={height:null,width:null,popup_text:null,popup_box:null,margins:{left:20,right:20,top:20,bottom:20},xaxis:{label_style:"",minvalue:null,maxvalue:null,dir:"+",label:"",line:null,scaling:"linear",major:1,minor:1,axis_pos:"below",labelsize:14,size:10,ticksize:4,values:[],label_scale:0,label_dp:0,label_suffix:""},yaxis:{label_style:"",minvalue:null,maxvalue:null,dir:"-",label:"",line:null,scaling:"linear",major:1,minor:1,axis_pos:"left",labelsize:14,size:10,ticksize:4,values:[],label_scale:0,label_dp:0,label_suffix:""},background:"#eee",title:{text:void 0,position:"above",size:20,fill:"#000",offset:5},edge:"",notIE:!0};Raphael.fn.cs_merge=function(a,c){var b,d,f;for(d in a)if("function"!==typeof a[d])if(b=a[d],"object"===typeof c[b])for(f in this.cs[b])"function"!==typeof this.cs[b][f]&&"undefined"!==typeof c[b][f]&&(this.cs[b][f]=c[b][f]);else"undefined"!==typeof c[b]&&(this.cs[b]=c[b])};Raphael.fn.cs_init=function(a){Chartsmith_Collector[a.object]=this;this.cs=cs_defaults;this.notIE=document.all?!1:!0;this.cs_merge(["xaxis","yaxis","background","title","edge"],a);this.cs.width=$("#"+a.object).width();this.cs.height=$("#"+a.object).height();this.setSize(this.cs.width,this.cs.height);this.cs.yaxis.label&&(this.cs.margins.left+=this.cs.yaxis.labelsize);if("left"===this.cs.yaxis.axis_pos||"discrete"===this.cs.yaxis.scaling||"on"===this.cs.yaxis.axis_pos&&("log"===this.cs.yaxis.scaling?1:0)<this.cs.yaxis.minvalue)this.cs.margins.left+=6*this.cs.yaxis.size+10;this.cs.xaxis.label&&(this.cs.margins.bottom+=this.cs.xaxis.labelsize,this.cs.title.offset+=this.cs.xaxis.labelsize);if("below"===this.cs.xaxis.axis_pos||"discrete"===this.cs.xaxis.scaling||"on"===this.cs.xaxis.axis_pos&&("log"===this.cs.xaxis.scaling?1:0)<this.cs.xaxis.minvalue)this.cs.margins.bottom+=this.cs.xaxis.size+10,this.cs.title.offset+=this.cs.xaxis.size+10;this.cs.title.text&&"below"===this.cs.title.position&&this.cs.title.text&&(this.cs.margins.bottom+=this.cs.title.size);this.cs.title.text&&"below"!==this.cs.title.position&&this.cs.title.text&&(this.cs.margins.top+=this.cs.title.size);this.cs_merge(["margins"],a);if(!this.cs.edge)this.cs.edge=this.cs.background;this.cs_draw_canvas()};Raphael.fn.cs_tweak_axis=function(a){var c,b;a.length=a.end-a.start;if("discrete"===a.scaling){c=a.values;a.mult=a.length/c.length;a.invert={};for(b=c.length;b;b--)a.invert[c[b-1]]=b-1}else"log"===a.scaling?a.mult=a.length/Math.log(a.maxvalue/a.minvalue):(a.cp=(a.start+a.end)/2,a.mult=a.length/(a.maxvalue-a.minvalue))};Raphael.fn.cs_draw_canvas=function(){var a,c,b,d,f,e,g,h,i;this.cs.xaxis.start=this.cs.margins.left;this.cs.xaxis.end=this.cs.width-this.cs.margins.right;this.cs.yaxis.start=this.cs.margins.top;this.cs.yaxis.end=this.cs.height-this.cs.margins.bottom;this.cs_tweak_axis(this.cs.xaxis);this.cs_tweak_axis(this.cs.yaxis);if("below"===this.cs.xaxis.axis_pos||"discrete"===this.cs.yaxis.scaling)this.cs.xaxis.pos=this.cs.yaxis.end;else if(this.cs.xaxis.pos=this.cs_scale_y("log"===this.cs.yaxis.scaling?1:0),"+"===this.cs.xaxis.pos||"-"===this.cs.xaxis.pos)this.cs.xaxis.pos=this.cs.yaxis.end;if("left"===this.cs.yaxis.axis_pos||"discrete"===this.cs.xaxis.scaling)this.cs.yaxis.pos=this.cs.xaxis.start;else if(this.cs.yaxis.pos=this.cs_scale_x("log"===this.cs.xaxis.scaling?1:0),"+"===this.cs.yaxis.pos||"-"===this.cs.yaxis.pos)this.cs.yaxis.pos=this.cs.xaxis.start;this.rect(this.cs.xaxis.start,this.cs.yaxis.start,this.cs.xaxis.length,this.cs.yaxis.length).attr({fill:this.cs.background,stroke:this.cs.edge});this.cs.title.text&&this.cs_add_text({raw:1,x:(this.cs.xaxis.start+this.cs.xaxis.end)/2,y:"below"===this.cs.title.position?this.cs.yaxis.end+this.cs.title.offset+this.cs.title.size/2:this.cs.title.size/2+5,t:this.cs.title.text,opts:{fill:this.cs.title.fill,"font-size":this.cs.title.size+"px","font-weight":"bold"}});a=this.cs_get_ticks(this.cs.xaxis);c=this.cs_get_ticks(this.cs.yaxis);for(b=a.length;b;b--)d=a[b-1],d.line&&this.cs_add_line({raw:1,stroke:d.line,pts:[d.pos,this.cs.yaxis.start,d.pos,this.cs.yaxis.end]}),this.cs_add_line({raw:1,stroke:"#000",pts:[d.pos,this.cs.xaxis.pos,d.pos,this.cs.xaxis.pos+this.cs.xaxis.ticksize]}),"undefined"!==typeof d.label&&(f=d.label.toString(),(g=f.match(/^10\^(-?\d+)(\w*)$/))?(f=0,g[3]&&(e=this.cs_add_text({raw:1,x:d.pos,y:this.cs.xaxis.pos+this.cs.xaxis.ticksize+this.cs.xaxis.size/2+8,t:g[2],opts:{fill:"#000","font-size":this.cs.xaxis.size+"pt"}}),f=e.getBBox().width/2),h=this.cs_add_text({raw:1,x:d.pos,y:this.cs.xaxis.pos+this.cs.xaxis.ticksize+this.cs.xaxis.size/2+8-3,t:g[1],opts:{fill:"#000","font-size":0.6*this.cs.xaxis.size+"pt"}}),g=h.getBBox().width/2,i=this.cs_add_text({raw:1,x:d.pos,y:this.cs.xaxis.pos+this.cs.xaxis.ticksize+this.cs.xaxis.size/2+8,t:"10",opts:{fill:"#000","font-size":this.cs.xaxis.size+"pt"}}),d=i.getBBox().width/2,e&&e.translate(g+d,0),h.translate(d-f,0),i.translate(-f-g,0)):this.cs_add_text({raw:1,x:d.pos,y:this.cs.xaxis.pos+this.cs.xaxis.ticksize+this.cs.xaxis.size/2+8,t:d.label,opts:{fill:"#000","font-size":this.cs.xaxis.size+"pt"}}));for(b=c.length;b;b--)d=c[b-1],d.line&&this.cs_add_line({raw:1,stroke:d.line,pts:[this.cs.xaxis.start,d.pos,this.cs.xaxis.end,d.pos]}),this.cs_add_line({raw:1,stroke:"#000",pts:[this.cs.yaxis.pos,d.pos,this.cs.yaxis.pos-this.cs.yaxis.ticksize,d.pos]}),"undefined"!==typeof d.label&&(a=d.label.toString(),(a=a.match(/^10\^(-?\d+)(\w*)$/))?(a[2]&&this.cs_add_text({align:"right",raw:1,x:this.cs.yaxis.pos-this.cs.yaxis.ticksize-5,y:d.pos,t:a[2],opts:{fill:"#000","font-size":this.cs.yaxis.size+"pt"}}),a=this.cs_add_text({align:"right",raw:1,x:this.cs.yaxis.pos-this.cs.yaxis.ticksize-5,y:d.pos-3,t:a[1],opts:{fill:"#000","font-size":0.6*this.cs.yaxis.size+"pt"}}),a=2*a.attrs.x-this.cs.yaxis.pos+this.cs.yaxis.ticksize-3,this.cs_add_text({align:"right",raw:1,x:a,y:d.pos,t:"10",opts:{fill:"#000","font-size":this.cs.yaxis.size+"pt"}})):this.cs_add_text({align:"right",raw:1,x:this.cs.yaxis.pos-this.cs.yaxis.ticksize-5,y:d.pos,t:d.label,opts:{fill:"#000","font-size":this.cs.yaxis.size+"pt"}}));this.cs.yaxis.label&&(a=this.cs_add_text({raw:1,x:this.cs.yaxis.labelsize/2+5,y:this.cs.yaxis.start+this.cs.yaxis.length/2,t:this.cs.yaxis.label,opts:{fill:"#000",font:this.cs.yaxis.labelsize+"px Arial","font-weight":"bold"}}),a.rotate(-90));this.cs_add_line({raw:1,stroke:"#000",pts:[this.cs.xaxis.start,this.cs.xaxis.pos,this.cs.xaxis.end,this.cs.xaxis.pos]});this.cs.xaxis.label&&this.cs_add_text({raw:1,y:this.cs.yaxis.end+this.cs.xaxis.labelsize/2+24,x:this.cs.xaxis.start+this.cs.xaxis.length/2,t:this.cs.xaxis.label,opts:{fill:"#000",font:this.cs.xaxis.labelsize+"px Arial","font-weight":"bold"}});this.cs_add_line({raw:1,stroke:"#000",pts:[this.cs.yaxis.pos,this.cs.yaxis.start,this.cs.yaxis.pos,this.cs.yaxis.end]})};Raphael.fn.cs_get_ticks=function(a){var c=[],b,d,f,e,g,h;if("log"===a.scaling){b=Math.floor(Math.log(a.minvalue)/Math.log(10));d=Math.ceil(Math.log(a.maxvalue)/Math.log(10));for(f=Math.pow(10,a.major);b<=d;b+=a.major){g=e=Math.pow(10,b);if("scientific"===a.label_style||"best_scientific"===a.label_style&&3<Math.abs(b))g="10^"+b+a.label_suffix;h=this.cs_scale(a,e);"+"!==h&&"-"!==h&&c.push({pos:h,label:g,line:a.line});if(a.minor)for(h=a.minor;h<f;h+=a.minor)g=h*e,g=this.cs_scale(a,g),"+"!==g&&"-"!==g&&c.push({pos:g})}return c}if("discrete"===a.scaling){for(b=a.values.length;b;b--)d=a.values[b-1],c.push({pos:this.cs_scale(a,d),label:d});return c}b=Math.floor(a.minvalue/a.major);d=Math.ceil(a.maxvalue/a.major);for(f=b;f<=d;f++)if(b=f*a.major,h=this.cs_scale(a,b),"+"!==h&&"-"!==h&&(e=b,a.label_scale&&(e/=a.label_scale,e="scientific"===a.label_style||"best_scientific"===a.label_style&&3<Math.abs(b)?parseFloat(e).toExponential(a.label_dp)+a.label_suffix:parseFloat(e).toFixed(a.label_dp)+a.label_suffix),c.push({pos:h,label:e,line:a.line})),a.minor){e=a.major/a.minor;for(h=1;h<a.minor;h++)g=b+h*e,g=this.cs_scale(a,g),"+"!==g&&"-"!==g&&c.push({pos:g})}return c};Raphael.fn.cs_scale_x=function(a){return this.cs_scale(this.cs.xaxis,a)};Raphael.fn.cs_scale_y=function(a){return this.cs_scale(this.cs.yaxis,a)};Raphael.fn.cs_scale=function(a,c){var b="",b=0,d=c;if("-"===a.dir){if("discrete"===a.scaling){if("object"===typeof c&&(d=c.val,"undefined"!==typeof c.off))b=c.off;1>Math.abs(b)&&(b*=a.mult);return a.end-a.mult*(a.invert[d]+0.5)-b}if("log"===a.scaling&&0>=c)return"+";b=a.start+a.mult*("log"===a.scaling?Math.log(a.maxvalue/c):a.maxvalue-c)}else{if("discrete"===a.scaling){if("object"===typeof c&&(d=c.val,"undefined"!==typeof c.off))b=c.off;1>Math.abs(b)&&(b*=a.mult);return a.start+a.mult*(a.invert[d]+0.5)+b}if("log"===a.scaling&&0>=c)return"-";b=a.start+a.mult*("log"===a.scaling?Math.log(c/a.minvalue):c-a.minvalue)}return b<a.start-0.5?"-":b>a.end+0.5?"+":b};Raphael.fn.cs_shape=function(a,c,b,d){var f=d;if("object"===typeof a)return c=this.path(a.path).translate(c,b),a.scale_factor?c.scale(d/a.scale_factor):c.scale(d),c;switch(a){case "square":f*=Math.sqrt(Math.PI)/2;a="m-1 -1l0 2l2 0l0 -2";break;case "diamond":f*=Math.sqrt(Math.PI/2);a="m-1 0l1 1l1 -1l-1 -1";break;case "cross":case "+":f*=Math.sqrt(Math.PI/40);a="m-3 1l2 0l0 2l2 0l0 -2l2 0l0 -2l-2 0l0 -2l-2 0l0 2l-2 0 l";break;case "x":f*=Math.sqrt(Math.PI/20);a="m-3 1l2 0l0 2l2 0l0 -2l2 0l0 -2l-2 0l0 -2l-2 0l0 2l-2 0 l";break;case "<":case "left":a="m-1.904625 0 2.856938 1.649454 0 -3.298908";break;case "right":case ">":a="m1.904625 0 -2.856938 1.649454 0 -3.298908";break;case "v":case "V":case "down":a="m0 -1.34677 1.16634 0.67339 -1.16634 0.667339";break;case "^":case "up":a="m0 1.34677 1.16634 -0.67339 -1.16634 -0.667339";break;default:return this.circle(c,b,d)}return this.path("M"+c+" "+b+a.replace(/(-?\d+(\.\d+)?)/g,function(a){return a*f})+"z")};Raphael.fn.cs_add_points=function(a,c){var b=this.set(),d,f={radius:5,edge:void 0,opacity:0.5,col:"#000",shape:"circle",show_label:!1,popup:!0,"stroke-width":1},e,g,h,i,m,j,k,l,n,p,o=this,q,r;if("object"===typeof c)for(d in c)"undefined"!==typeof c[d]&&(f[d]=c[d]);r=function(){o.cs_draw_balloon({x:this.attrs.cx,y:this.attrs.cy,radius:this.attrs.r,t:this.attrs.balloontext})};q=function(){if(o.popup_text)o.popup_text.remove(),o.popup_text=null,o.popup_box.remove()};for(d=a.length;d;d--){e=a[d-1];g=this.cs_scale_x(e.x);h=this.cs_scale_y(e.y);if("-"===g||"-"===h||"+"===g||"+"===h)return null;for(k in f)"function"!==typeof f[k]&&"undefined"===typeof e[k]&&(e[k]=f[k]);i=this.cs_shape(e.shape,g,h,e.radius);if("undefined"===typeof e.edge)e.edge=e.col;i.attr({opacity:e.opacity,fill:e.col,stroke:e.edge,"stroke-width":e["stroke-width"]});i.attrs.cx=g;i.attrs.cy=h;i.attrs.r=e.radius;m=e.value+" \n("+this.cs_format_x(e.x)+","+this.cs_format_y(e.y)+")";e.label&&(m=e.label+" - "+m);e.show_label&&(j=this.cs_add_text({raw:1,x:g,y:h,t:e.label}),l=j.getBBox().width+Math.sqrt(0.75)*e.radius,n=j.getBBox().height+e.radius/2,j.remove(),p=g-this.cs.xaxis.start,j=h-this.cs.yaxis.start,p<l||p>this.cs.xaxis.length/2&&p<this.cs.xaxis_length-l?(l="left",g+=e.radius*Math.sqrt(0.75)):(l="right",g-=e.radius*Math.sqrt(0.75)),j<n||j>this.cs.yaxis.lenght/2&&j<this.cs.yaxis_length-n?(n="top",h+=e.radius/2):(n="bottom",h-=e.radius/2),this.cs_add_text({raw:1,x:g,y:h,t:e.label,align:l,valign:n,opts:{"font-size":"12px","font-weight":"bold"}}));if(e.popup)i.attrs.balloontext=m,i.mouseover(r),i.mouseout(q);b.push(i)}return b};Raphael.fn.cs_add_image=function(a){var c=a.x,b=a.y,d=a.h,f=a.w,e,g;a.l&&a.r?(e=a.l,f=a.r,a.raw||(e=this.cs_scale_x(e),f=this.cs_scale_x(f)),f<e&&(c=e,e=f,f=c),c=e,f-=e):(a.raw||(c=this.cs_scale_x(c)),0>f&&(f*=-this.cs.xaxis.length),"right"===a.align&&(c-=f),"center"===a.align&&(c-=0.5*f));a.t&&a.b?(b=a.t,d=a.b,a.raw||(b=this.cs_scale_x(b),d=this.cs_scale_x(d)),b<d&&(g=d,d=b,b=g),d-=e):(a.raw||(b=this.cs_scale_y(b)),0>d&&(d*=-this.cs.yaxis.length),"top"===a.valign&&(b-=d),"center"===a.valign&&(b-=0.5*d));b=this.image(a.name,c,b,f,d);a.opts&&b.attr(a.opts);return b};Raphael.fn.cs_add_text=function(a){var c;c=a.raw?this.text(a.x,a.y,a.t.toString()):this.text(this.cs_scale_x(a.x),this.cs_scale_y(a.y),a.t.toString());a.opts&&c.attr(a.opts);"right"===a.align&&c.translate(-c.getBBox().width/2,0);"left"===a.align&&c.translate(c.getBBox().width/2,0);"top"===a.valign&&c.translate(0,c.getBBox().height/2);"bottom"===a.valign&&c.translate(0,-c.getBBox().height/2);return c};Raphael.fn.cs_lolight=function(a){a.attr("stroke-width",1);a.attrs.handles.hide();a.attrs.legend&&a.attrs.legend.attr("stroke-width",1);if(this.popup_text)this.popup_text.remove(),this.popup_text=null,this.popup_box.remove()};Raphael.fn.cs_hilight=function(a){var c=a.attrs.data_pts,b=30,d=Math.cos(b*Math.PI/180),f=c.length,e=Math.sin(b*Math.PI/180),g,h,i,m,j,k,l,n;this.cs.line&&this.cs.lolight(this.cs.line);a.attrs.legend&&a.attrs.legend.attr("stroke-width",4);b=30;d=Math.cos(b*Math.PI/180);f=c.length;e=Math.sin(b*Math.PI/180);for(g=c.length;g;g--)h=c[g-1],a.attrs.handles.push(this.circle(h.xp,h.yp,6).attr({fill:a.attrs.colour,stroke:a.attrs.colour})),i="("+h.x+","+h.y+")",m=this.text(h.xp,h.yp,i).attr({fill:this.cs.background,stroke:this.cs.background,"stroke-width":4}),j=m.getBBox().width+20,k=-1,l=1,h.xp+d*j<this.cs.xaxis.end?g<f&&h.yp>c[g].yp&&(k=1):(l=-1,k=1,1<g&&c[g-2].yp>h.yp&&(k=-1)),n=d*j/2*l,j=e*j/2*k,k=-1===l?-b*k:b*k,m.rotate(k,!1),m.translate(n,j),a.attrs.handles.push(m),a.attrs.handles.push(this.text(h.xp+n,h.yp+j,i).rotate(k,!1).attr({fill:"#000","stroke-width":0.1,stroke:"#000"}));c=(a.attrs.data_pts[Math.floor(f/2)].xp+a.attrs.data_pts[Math.ceil(f/2)].xp)/2;f=(a.attrs.data_pts[Math.floor(f/2)].yp+a.attrs.data_pts[Math.ceil(f/2)].yp)/2;a.attr("stroke-width",4);this.cs_draw_balloon({x:c,y:f,radius:1,t:a.attrs.balloontext});a.attrs.handles.show().toFront();this.notIE&&a.toFront();this.cs.line=a};Raphael.fn.cs_format_x=function(a){return this.cs_format(this.cs.xaxis,a)};Raphael.fn.cs_format_y=function(a){return this.cs_format(this.cs.yaxis,a)};Raphael.fn.cs_format=function(a,c){return"discrete"===a.scaling?"object"===typeof c?c.val:c:parseFloat(c).toFixed(3)};Raphael.fn.cs_add_line=function(a){var c=a.pts.length,b,d=[],f,e=this;if(a.raw)for(b=0;b<c;b+=2)d.push({x:this.cs_format_x(a.pts[b]),y:this.cs_format_y(a.pts[b+1]),xp:a.pts[b],yp:a.pts[b+1]});else for(b=0;b<c;b+=2)d.push({x:this.cs_format_x(a.pts[b]),y:this.cs_format_y(a.pts[b+1]),xp:this.cs_scale_x(a.pts[b]),yp:this.cs_scale_y(a.pts[b+1])});c=d.length;f="M"+d[0].xp+" "+d[0].yp;for(b=1;b<c;b++)f+="L"+d[b].xp+" "+d[b].yp;c=this.path(f).attr({stroke:a.stroke});a.opts&&c.attr(a.opts);if(a.label)c.attrs.balloontext=a.label,c.attrs.data_pts=d,c.attrs.handles=this.set(),c.attrs.colour=a.stroke,c.attrs.handles.hide(),c.mouseover(function(){e.cs.hilight(this)});return c};Raphael.fn.cs_add_poly=function(a){var c=a.pts.length,b,d;if(a.raw){d="M"+a.pts[0]+" "+a.pts[1];for(b=2;b<c;b+=2)d+="L"+a.pts[b]+" "+a.pts[b+1]}else{d="M"+this.cs_scale_x(a.pts[c-2])+" "+this.cs_scale_y(a.pts[c-1]);for(b=0;b<c;b+=2)d+="L"+this.cs_scale_x(a.pts[b])+" "+this.cs_scale_y(a.pts[b+1])}c=this.path(d+"z").attr({fill:a.fill,stroke:a.stroke});a.opts&&c.attr(a.opts);return c};Raphael.fn.cs_draw_balloon=function(a){var c,b,d,f,e;if(this.cs.popup_text)this.cs.popup_text.remove(),this.cs.popup_text=null,this.cs.popup_box.remove();this.cs.popup_text=this.text(a.x,a.y,a.t);d=a.x-this.cs.xaxis.start>this.cs.xaxis.length/2;c=this.cs.popup_text.getBBox().width;b=this.cs.popup_text.getBBox().height;f=a.radius+40+c/2;e=-10;d&&(f*=-1);a.y-b/2-10<this.cs.yaxis.start&&(e=-a.y+10+b/2+this.cs.yaxis.start);a.y+b/2+10>this.cs.yaxis.end&&(e=a.y-this.cs.yaxis.end-b/2);this.cs.popup_text.translate(f,e);a="M"+(a.x+(d?-1:1)*a.radius)+" "+a.y;this.cs.popup_box=this.path(d?a+(" l -35 "+(4+e)+" l 0 "+(b/2-4)+" a5 5 0 0 1 -5 5 l -"+c+" 0 a5 5 0 0 1 -5 -5 l 0 -"+b+" a 5 5 0 0 1 5 -5 l "+c+" 0 a 5 5 0 0 1 5 5 l 0 "+(b/2-4)+" z"):a+(" l 35 "+(4+e)+" l 0 "+(b/2-4)+" a5 5 0 0 0 5 5 l "+c+" 0 a5 5 0 0 0 5 -5 l 0 -"+b+" a 5 5 0 0 0 -5 -5 l -"+c+" 0 a 5 5 0 0 0 -5 5 l 0 "+(b/2-4)+" z")).attr({stroke:"#000",fill:"#fff"});this.cs.popup_box.insertBefore(this.cs.popup_text)};