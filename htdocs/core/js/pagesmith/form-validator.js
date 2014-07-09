(function(){
  'use strict';
  /*jslint regexp: true */
  /*global escape */
  // $Revision$

  var XHTMLValidator = {
    ent: /&(amp|lt|gt|quot|apos);/i,

    ats: { 'class': 1, title: 1, id: 1, style: 1 },

    nts: {
      img   : { rt: 1, tx: 0, at: { src: 1, alt: 1, title: 1 }, tg: {} },
      a     : { rt: 1, tx: 1, at: { href: 1, name: 1, rel: 1 }, tg: { img: 1, span: 1, em: 1, i: 1, strong: 1 } },
      strong: { rt: 1, tx: 1, at: {}, tg: { img: 1, a: 1, em: 1, i: 1, span: 1 } },
      i     : { rt: 1, tx: 1, at: {}, tg: { img: 1, strong: 1, em: 1, a: 1, span: 1 } },
      em    : { rt: 1, tx: 1, at: {}, tg: { img: 1, strong: 1, i: 1, em: 1, a: 1, span: 1 } },
      p     : { rt: 1, tx: 1, at: {}, tg: { img: 1, strong: 1, em: 1, i: 1, a: 1, span: 1 } },
      span  : { rt: 1, tx: 1, at: {}, tg: { img: 1, strong: 1, em: 1, i: 1, a: 1, span: 1 } },
      li    : { rt: 0, tx: 1, at: {}, tg: { span: 1, p: 1, img: 1, strong: 1, em: 1, i: 1, a: 1, ul: 1, ol: 1, dl: 1 } },
      dt    : { rt: 0, tx: 1, at: {}, tg: { span: 1, p: 1, img: 1, strong: 1, em: 1, i: 1, a: 1, ul: 1, ol: 1, dl: 1 } },
      dd    : { rt: 0, tx: 1, at: {}, tg: { span: 1, p: 1, img: 1, strong: 1, em: 1, i: 1, a: 1, ul: 1, ol: 1, dl: 1 } },
      ol    : { rt: 1, tx: 0, at: {}, tg: { li: 1 } },
      ul    : { rt: 1, tx: 0, at: {}, tg: { li: 1 } },
      dl    : { rt: 1, tx: 0, at: {}, tg: { dd: 1, dt: 1} }
    },

    trim: function (s) {
      s+='';
      return s.replace(/\s+/g, ' ').replace(/^\s+/, '').replace(/\s+$/, '');
    },

    validate: function (string) {
      var myself = this, error, err = 0, a = [], stack = [];

      // Firstly split the HTML up into tg and entries
      $.each(this.trim(string).split(/(?=<)/), function (i, w) {
        if (w.substr(0, 1) === '<') {
          var x = w.match(/^([^>]+>)([^>]*)$/);
          if (x) {
            a.push(x[1]);
            if (x[2].match(/\S/)) {
              a.push(x[2]);
            }
          } else {
            err = 'Not well-formed: "' + myself.trim(w) + '"';
          }
        } else if (w.match(/>/)) {
          err = 'Not well-formed: "' + myself.trim(w) + '"';
        } else if (w.match(/\S/)) {
          a.push(w);
        }
      });

      if (err) {
        return err;
      }


      $.each(a, function (i, w) {
        var LN = stack[0], TN, ATS, SCL, cls, LAST, tag, m, AN, vl, parts, ip, e;

        // This is a tag
        if (w.substr(0, 1) === '<') {
          TN = '';
          ATS = '';
          SCL = '';
          cls = w.match(/<\/(\w+)>/);

          if (cls) {
            if (stack.length === 0) {
              error = 'Attempt to close too many tags "/' + cls[1] + '"';
            } else {
              LAST = stack.shift();
              if (LAST !== cls[1]) {
                err = 'Mismatched tag "/' + cls[1] + '" !== "' + LAST + '"';
              }
            }
          } else {
            tag = w.match(/<(\w+)(.*?)(\/?)>/);

            if (tag) {
              TN = tag[1];
              if (TN.match(/[A-Z]/)) {
                err = 'Non lower-case tag: "' + TN + '".';
              } else {
                if (!myself.nts[TN]) { // Return an error if we don't allow the tag
                  err = 'Tag "' + TN + '" not allowed';
                } else if (LN && !myself.nts[LN].tg[TN]) { // Return an error if this is nested in an invalid parent
                  err = 'Tag "' + TN + '" not allowed in "' + stack[stack.length - 1] + '"';
                } else if (!LN && !myself.nts[TN].rt) { // Return an error if this tag has to be embeded in another tag and isn't
                  err = 'Tag "' + TN  + '" not allowed at top level';
                } else {
                  ATS = tag[2];
                  SCL = tag[3] === '/' ? 1 : 0;
                  if (!SCL) {
                    stack.unshift(TN);
                  }
                  if (ATS) {
                    m = ATS.match(/^\s+(\w+)\s*=\s*"([^"]*)"(.*)$/);
                    /* jshint -W073 */
                    while (m) {
                      AN = m[1];
                      vl = m[2];
                      if (AN.match(/[A-Z]/)) {
                        err = 'Non lower case attr name "' + AN + '" in tag "' + TN + '".';
                      } else {
                        if (myself.ats[AN] || myself.nts[TN].at[AN]) {
                          parts = vl.split(/(?=&)/);
                          for (ip = parts.length; ip; ip) {
                            ip--;
                            e = parts[ip];
                            if (e.substr(0, 1) === '&' && !e.match(myself.ent)) {
                              err = 'Unknown entity "' + e + '" in attr "' + AN + '" in tag "' + TN + '".';
                            }
                          }
                        } else {
                          err = 'Attr "' + AN + '" not valid in tag "' + TN + '".';
                        }
                      }
                      ATS = m[3];
                      m = ATS.match(/^\s+(\w+)\s*=\s*"([^"]*)"(.*)$/);
                    }
                    if (ATS.match(/\S/)) {
                      err = 'Problem with tag "' + TN + '"\'s attrs (' + ATS + ').';
                    }
                    /* jshint +W073 */
                  }
                }
              }
            } else {
              err = 'Malformed tag "' + w + '"';
            }
          }
        } else { // This is raw HTML
          if (LN && !myself.nts[LN].tx) { // Return an err if in a tag which can't contain raw text
            err = 'No raw text allowed in "' + LN + '"';
          } else { // Now check all entities
            $.each(w.split(/(?=&)/), function (j, e) {
              if (e.substr(0, 1) === '&' && !e.match(myself.ent)) {
                err = 'Unknown entity "' + myself.trim(e) + '"';
              }
            });
          }
        }
        if (err) {
          return;  // Skip out of the loop
        }
      });
      if (!err && stack.length > 0) {
        return 'Unclosed tags "' + stack.join(' ') + '"';
      }
      return err;
    }
  };

/* jshint -W074 */
  var FormValidator = {
    colours: {
      required: '#fec',
      optional: '#fff',
      error:    '#fcc',
      valid:    '#cfc',
      supervalid: '#8f8'
    },
    password_strength: function (s) {
  /*jsl:ignore*/
      return (
        (s.match(/[A-Z]/) ? 1 : 0) +
        (s.match(/[a-z]/) ? 1 : 0) +
        (s.match(/[0-9]/) ? 1 : 0) +
        (s.match(/[^0-9A-Za-z]/) ? 1 : 0)
      );
  /*jsl:end*/
    },
    trim: function (s) {
      s+=''; // Stringify object incase empty!
      return s.replace(/^(\s+)?(.*\S)(\s+)?$/, '$2');
    },

    isInt:     function (s) { return s.match(/^[\-+]?\d+$/); },
    isRef:     function (s) { return s.match(/^(SID_)?\d+$/); },
    isRefList: function (s) { return s.match(/^\s*((SID_)?\d+\s+)*(SID_)?\d+\s*$/); },
    isIntList: function (s) { return s.match(/^[\d\s]+$/); },
    isFloat:   function (s) { return s.match(/^[\-+]?(\d+\.\d+|\d+\.?|\.\d+)?([Ee][\-+]?\d+)?$/); },
    isEmail:   function (s) { return s.match(/^[^@]+@[^@.:]+[:.][^@]+$/); },
    isURL:     function (s) { return s.match(/^https?:\/\/\w.*$/); },
    isURI:     function (s) { return s.match(/^(ftp|https?):\/\/\w.*$/); },
    isPass:    function (s,el) {
      var ml = el.prop('className').match(/min_(\d+)/);
      return s.length >= ( ml ? ml[1] : 6 );
    },
    isStrong:  function (s, n) { return this.password_strength(s) < n ? 0 : 1; }, // Requires 3 of lc, uc, digit, symbol
    isCode:    function (s) { return s.match(/^\S+$/); },
    isAlpha:   function (s) { return s.match(/^\w+$/); },
    isHTML:    function (s) { return !XHTMLValidator.validate(s); },

    validators: {
      vstrongpassword:  function(that,s,el) { return [ that.isPass(s,el) && that.isStrong(s, 4) ? 1 : (that.isPass(s,el) ? false : false), []]; },
      strongpassword:   function(that,s,el) { return [ that.isPass(s,el) && that.isStrong(s, 3) ? 1 : (that.isPass(s,el) ? false : false), []]; },
      normalpassword:   function(that,s,el) { return [ that.isPass(s,el) && that.isStrong(s, 2) ? 1 : (that.isPass(s,el) ? false : false), []]; },
      weakpassword:     function(that,s,el) { return [ that.isPass(s,el) && that.isStrong(s, 1) ? 1 : (that.isPass(s,el) ? false : false), []]; },
      password:         function(that,s,el) { return [ that.isPass(s,el), []]; },
      even:             function(that,s) { return [ that.isInt(s) && (parseInt(s,10)%2 === 0), []]; },
      odd:              function(that,s) { return [ that.isInt(s) && (parseInt(s,10)%2 === 1), []]; }
    },
    valid: function (el, s) {
      var m, els, optgp, v, cl, max;
      if (el.is('select')) {
        if (el.hasClass('match_group_class')) {
          m = el.prop('className').match(/\b(_group_\d+)\b/);
          if (m) {
            els = el.closest('form').find('.' + m[1]);
            optgp = '';
            v = true;
            els.each(function (i, e) {
              var newopt = $(e).find('option').eq($(e).prop('selectedIndex')).parent().prop('className');
              if (optgp === '') {
                optgp = newopt;
              } else {
                if (optgp !== newopt) {
                  v = false;
                }
              }
            });
            return [v, els];
          }
        } else {
          return [true, []];
        }
      }

      cl  = el.prop('className').replace(/.*\b_(\w+)\b.*/, '$1');
      if (el.hasClass('_max_len')) {
        cl  = 'max_len';
      }
      max = el.prop('className').match(/\bmax_(\d+)\b/);
      if( this.validators[cl] ) {
        return this.validators[cl](this,s,el);
      } else {
        switch (cl) {
          case 'max_len':
            return [this.update_count(el), []];
          case 'int':
            return [this.isInt(s),    []];
          case 'float':
            return [this.isFloat(s),  []];
          case 'email':
            return [this.isEmail(s),  []];
          case 'url_fetch_title':
            return [this.isURL(s),    []];
          case 'url':
            return [this.isURL(s),    []];
          case 'uri_fetch_title':
            return [this.isURI(s),    []];
          case 'uri':
            return [this.isURI(s),    []];
          case 'password':
            return [this.isPass(s,el),   []];
          case 'code':
            return [this.isCode(s),   []];
          case 'alpha':
            return [this.isAlpha(s), []];
          case 'html':
            return [this.isHTML(s), []];
          case 'file':
            return [true, []];
          case 'age':
            return [this.isInt(s)   && parseInt(s, 10)   >= 0 && parseInt(s, 10) <= 150, []];
          case 'pubmed_list':
            return [this.update_count(el) && this.isRefList(s), []];
          case 'pubmed':
            return [this.isRef(s), []];
          case 'posint':
            return [this.isInt(s)   && parseInt(s, 10)   >  0 && (max === null || parseInt(s, 10) <= max[1]), []];
          case 'nonnegint':
            return [this.isInt(s)   && parseInt(s, 10)   >= 0 && (max === null || parseInt(s, 10) <= max[1]), []];
          case 'posfloat':
            return [this.isFloat(s) && parseFloat(s) >  0, []];
          case 'nonnegfloat':
            return [this.isFloat(s) && parseFloat(s) >= 0, []];
          default:
            return [true, []];
        }
      }
    },

    update_count: function (el) {
      var text    = this.trim(el.val()).toString(), d = el.closest('dd').find('.max_len'), max_len = parseInt(d.find('.max').text(), 10), units = d.find('.units').text(), count = 0, T;
      if (units === 'words' || units === 'ids') {
        T = text.match(/\b(\w+-\w+|\w+'\w\w?|\w+)\b/g);
        count = T ? T.length : 0;
      } else {
        count = text.length;
      }
      d.find('.count').html(count);
      return count <= max_len ? true : false;
    },
    load_pubmed: function (el) {
      var val = this.trim(el.val()), T, html_string;
      if (this.isRefList(val)) {
        el.closest('dd').find('p').remove();
        T = el.closest('dd').find('ul');
        html_string = '<div class="ajax" title="/action/component/References?pars=-show_errors+' + escape(val) + '"><ul><li>Retrieving details</li></ul></div>';
        if (T.length) {
          T.replaceWith(html_string);
        } else {
          el.closest('dd').append(html_string);
        }
      }
    },
    load_url: function (el) {
      var val = this.trim(el.val());
      el.closest('dd').find('p').remove();
      if( val && val.match(/^https?:/) ) {
        el.closest('dd').append('<p><span class="ajax" title="/action/component/Link?pars=-get_title+' + escape(val) + '">Retrieving title</span></p>');
      }
      return;
    },
    check: function (el) {
      var required     = el.hasClass('required'),
          class_string = 'col-required col-optional col-error col-valid col-supervalid',
          value, flag, myform, o, mynext;

      if (!required && !el.hasClass('optional')) {
        return;
      }

      value = this.trim(el.val());
      flag  = this.valid(el, value);
      /* We have to do something very clever with files! - as required should be set
         - IF there are non deleted files attached to the form already....
      */
      if (el.hasClass('_file') && value === '' &&
          $(el).closest('dd').find('input[type=checkbox]').not('[name$=all]').not(':checked').length &&
          ($(el).closest('dd').find('input[type=checkbox]').filter('[name$=all]').filter(':checked').length === 0)) {
        value = 1; // 'we have an attached file!'
      }
      if( el.hasClass('multiple') && value === '' && $(el).closest('dd').find('.close_box').length ) {
        required = 0;
      }
      if (flag[1].length) {
        o = this;
        flag[1].each(function (i, e) {
          var v = o.trim($(e).val());
          $(e).removeClass(class_string).addClass(v === '' ? (required ? 'col-required' : 'col-optional') : (flag[0] ? 'col-valid' : 'col-error'));
          if ($(e).hasClass('_checkbox')) {
            $(e).removeClass(class_string);
          }
        });
      } else {
        el.removeClass(class_string).addClass(value === '' ? (required ? 'col-required' : 'col-optional') : (flag[0] && flag[0] > 1 ? 'col-supervalid' : (flag[0] ? 'col-valid' : 'col-error')));
        if (el.hasClass('_checkbox')) {
          el.removeClass(class_string);
        }
      }
      myform = el.closest('form');
      mynext = myform.find('.next');

      this.getWarnings(myform);
      if (this.warnings.length > 0) {
        mynext.removeClass('valid').addClass('invalid');
      } else {
        mynext.removeClass('invalid').addClass('valid');
      }
    },

    submit: function (form) {
      this.getWarnings(form);
      if( form.hasClass('submitted') && form.hasClass('prevent_double_submit') ) {
        window.alert( 'You have already submitted the form' );
        return false;
      }

      // TODO: something nicer than an alert box
      if (this.warnings.length) {
        window.alert(this.warnings.join('\n') + '\nCorrect ' + (this.warnings.length > 1 ? 'these errors' : 'this error') + ' and try again');
        return false;
      }
      if (form.hasClass('confirm') && !window.confirm('Check the values you entered are correct before continuing')) {
        return false;
      }
      form.addClass('submitted');
      return true;
    },

    submit_button: function (form) {
      var action_node = form.find(':input[name="action"]'), my_action = action_node.attr('value'), result;
      if (my_action === 'cancel') {
        if (form.hasClass('cancel_quietly')) {
          return 1;
        }
        return window.confirm('Are you sure you want to throw away the changes you have made - ON EVERY PAGE OF THIS FORM');
      }
      if (my_action === 'prev') {
        if ($(this).hasClass('prev_quietly')) {
          return 1;
        }
        return window.confirm('Go to previous page - note all value entered on this page will be lost?');
      }
      result = this.submit(form);
      action_node.attr('value', 'next');
      return result;
    },

    getWarnings: function (form) {
      var myself = this;

      this.warnings = []; // Clear old warnings

      $(':input', form).each(function () {
        var input = $(this), required = input.hasClass('required'), template, value, err, f, lab;

        if (!required && !input.hasClass('optional')) {
          return;
        }
        if( input.hasClass('multiple') && input.closest('dd').find('.close_box').length ) { // We already have something selected!
          required = 0;
        }

        value = myself.trim(input.val());
  /*jsl:ignore*/
        if (
          input.hasClass('_file') &&
            value === '' &&
            $(input).closest('dd').find('input[type=checkbox]').not('[name$=all]').not(':checked').length &&
            ($(input).closest('dd').find('input[type=checkbox]').filter('[name$=all]').filter(':checked').length === 0)
        ) {
          value = 1; // 'we have an attached file!'
        }
        if( input.hasClass('_checkbox') && !input.prop('checked') ) {
          value = '';
        }
  /*jsl:end*/
        if (input.is('select')) {
          if (value === '') {
            template = required ? 'You must select a value for %s' : '';
          } else {
            f = myself.valid(input, value);
            template = f[0] ? '' : 'Value selected for %s is incompatible with other selections';
          }
        } else {
          if (value === '') {
            template = required ? 'You must enter a value for %s' : '';
          } else if (input.hasClass('_html')) {
            err = XHTMLValidator.validate(value); // Validate as XHTML
            template = err ? 'The value of %s is invalid (' + err + ')' : '';
          } else {
            f = myself.valid(input, value);
            template = f[0] ? '' : 'The value of %s is invalid.'; // Check the types of parameters
          }
        }

        if (template) {
          lab = input.data('label');
          if (!lab) { lab = input.attr('name'); }
          myself.warnings.push(template.replace(/%s/, '\'' + lab + '\''));
        }
      });
    },

    check_logic: function (node) {
      var myself = this;
      if (!node.is('form')) {
        node = node.closest('form');
      }
      node.find('.logic').each(function () {
        var class_list = $(this).attr('class').split(/\s+/), logic = [], enabled = [], required = [], k, entry; // Every logic element....
        $.each(class_list, function (j, cls) {
          var M = cls.match(/^type-(\d+)-(\w+)$/);
          if (M) {
            logic[M[1]] = { type: M[2], action: '', conditions: [] };
          }
          M = cls.match(/^act-(\d+)-(\w+)$/);
          if (M) {
            logic[M[1]].action = M[2];
          }
          M = cls.match(/^node-(\d+)-(\w+)-(\w+)-(.*)$/);
          if (M) {
            logic[M[1]].conditions.push({ type: M[2], node: M[3], value: M[4] });
          }
        });
        // We will now check the conditions...
        for (k = 0; k <= logic.length; k++) {
          entry = logic[k];
          switch (entry.action) {
          case 'enable':
            if (enabled  === '') {
              enabled = 'disabled';
            }
            break;
          case 'disable':
            if (enabled  === '') {
              enabled = 'enabled';
            }
            break;
          case 'require':
            if (required === '') {
              required = 'optional';
            }
            break;
          default:
            if (required === '') {
              required = 'required';
            }
            break; /* optional */
          }
        }
        for (k = 0; k <= logic.length; k++) {
          entry = logic[k];
          if (myself.evaluate_logic(node, entry.type, entry.conditions)) {
            switch (entry.action) {
            case 'enable':
              enabled = 'enabled';
              break;
            case 'disable':
              enabled = 'disabled';
              break;
            case 'require':
              required = 'required';
              break;
            default:
              required = 'optional';
              break;  /* optional */
            }
          }
        }
        if (enabled === 'enabled') {
          if ($(this).is('div')) {
            $(this).removeClass('disabled');
          } else {
            $(this).closest('dd').removeClass('disabled').prev().filter('dt').removeClass('disabled');
          }
        }
        if (enabled === 'disabled') {
          if ($(this).is('div')) {
            $(this).addClass('disabled');
          } else {
            $(this).closest('dd').addClass('disabled').prev().filter('dt').addClass('disabled');
          }
        }
        if (required === 'required') {
          $(this).addClass('required').removeClass('optional');
        }
        if (required === 'optional') {
          $(this).addClass('optional').removeClass('requried');
        }
      });
    },

    evaluate_logic: function (frm, type, conditions) {
      var c, row, ty, vl, val, flag;
      if (conditions.length === 0) {
        return type === 'any' || type === 'all';
      }
      for (c = 0; c < conditions.length; c++) {
        row = conditions[c];
        ty = row.type;
        vl = row.value;
        val = $(frm).find('[name="' + row.node + '"]').val(); /* Look at removing disabled items */
        switch (ty) {
        case 'exact':
          flag = val === vl;
          break;
        case 'contains':
          flag = val.indexOf(vl) >= 0;
          break;
        case 'starts_with':
          flag = val.indexOf(vl) === 0;
          break;
        case 'ends_with':
          flag = val.lastIndexOf(vl) === (val.length - vl.length);
          break;
        case 'true':
          flag = !!vl;
          break;
        default:
          flag = 0;
          break;
        }
        switch (type) {
        case 'all':
          if (!flag) {
            return 0;
          }
          break;
        case 'any':
          if (flag) {
            return 1;
          }
          break;
        case 'none':
          if (flag) {
            return 0;
          }
          break;
        default:
          if (!flag) {
            return 1;
          }
          break; /* not_all */
        }
      }
      return type === 'all' || type === 'none';
    },

    push_label: function (node) {
      $('#' + node.attr('for')).data({'label': node.children('.hidden').length ? node.children('.hidden').html() : node.html()});
    }
  };

  // Now allocate functions....

  // Make elements of class autocomplete "james" objects...

  $(function () {
    if( $.james ) {
      Pagesmith.On.load('.auto_complete', function () {
        $(this).attr('autocomplete', 'off');
        var mat = $(this).attr('title').match(/^(\w+)=([^?]+)\??(.*)$/);
        if (mat) {
          $(this).james(mat[2], {params: mat[3], varname: mat[1], minlength: 2});
        }
        $(this).attr('title', '');
      });
    }
    $.fn.extend({
      toggleAttr : function (attrib) {
        if (this.attr(attrib)) {
          this.removeAttr(attrib);
        } else {
          this.attr(attrib, attrib);
        }
        return this;
      }
    });

    $('body').on(
      // "url" elements do a check of the URL
      'blur',
      'form ._fetch_title',
      function () {
        return FormValidator.load_url($(this));
      }
    ).on(// text area - with max length
      'change keyup',
      'form ._max_len',
      function () {
        return FormValidator.update_count($(this));
      }
    ).on(// and strings - with max length
      'change keyup blur',
      'form.check :input',
      function () {
        return FormValidator.check($(this));
      }
    ).on(// this element is refered to by a "logic" tag...
      'change',
      '.logic_change',
      function () {
        return FormValidator.check_logic($(this));
      }
    ).on(// "pubmed" elements get information about the paper!
      'blur',
      'form ._pubmed, form ._pubmed_list',
      function () {
        if (FormValidator.valid($(this), $(this).val())) {
          FormValidator.load_pubmed($(this));
        }
      }
    ).on(// Mouse down anywhere resets the action to the submit to next...
      'mousedown',
      'form.check',
      function () {
        $(this).closest('form').find(':input[name="action"]').attr('value', 'next');
      }
    ).on(// Mouse up on submit buttons sets the action to the value of the button
      'mouseup',
      'form.check :input[type="submit"]',
      function () {
        $(this).closest('form').find(':input[name="action"]').attr('value', $(this).attr('name'));
      }
    ).on(// action a submit button!
      'reset',
      'form.check',
      function () {
        $(this).find(':input').each(function () {
          return FormValidator.check($(this));
        });
      }
    ).on(// action a submit button!
      'submit',
      'form.check',
      function () {
        return FormValidator.submit_button($(this));
      }
    ).on(// multiple select
      'change',
      'select.multiple',
      function() {
        var nd    = $(this),
            sel_i = nd.prop('selectedIndex'),
            sel_t = $.trim(nd.find('option').eq([sel_i]).prop('text') ),
            sel_v = $.trim(nd.find('option').eq([sel_i]).prop('value')),
            in_node;
        if( typeof(sel_v) === 'undefined' ) {
          sel_v = sel_t;
        }
        if( sel_v !== '' ) {
          if(  ! nd.parent().find('span.close_box').filter(function(){ return $.trim($(this).text()) === sel_t; }).length ) {
            in_node = $('<input />').attr({name:nd.attr('name'),type:'hidden'}).prop( 'value', sel_v );
            nd.parent().append($('<span title="Click to remove" class="close_box" />').text(sel_t).append(in_node) );
          }
          nd[0].selectedIndex = 0;
          FormValidator.check(nd);
        }
      }
    ).on(// multiple input
      'blur',
      'input.multiple',
      function() {
        if($(this).attr('type') === 'file' || $(this).attr('type') === 'FILE' ) {
          return;
        }
        var nd   = $(this),
            in_t = $.trim(nd.val()),
            in_node;
        if( in_t !== '' ) {
          if( ! nd.parent().find('span.close_box').filter(function(){ return $.trim($(this).text()) === in_t; }).length ) {
            in_node = $('<input />').attr({name:nd.attr('name'),type:'hidden'}).prop( 'value', in_t );
            nd.parent().append($('<span title="Click to remove" class="close_box" />').text(in_t).append(in_node) );
          }
          nd.val('');
          FormValidator.check(nd);
        }
      }
    ).on(// Clicking on "file-blob" checkbox toggles "deleted" class on "row"
      'click',
      '.checkbox',
      function () {
      // Separate into delete all AND delete one...
        $(this).filter('[name$=_del_all]').closest('.file-details').toggleClass('deleted').closest(
          'table').find('tbody').not('.foot').toggleClass('all-deleted').find('input').toggleAttr(
          'disabled').end().find('img').closest('span').toggleClass('opac20');
        $(this).not('[name$=_del_all]').closest('.file-details').toggleClass('deleted').find('img').toggleClass(
          'opac20').end().prev().filter('.file-blob').toggleClass('opac20');
        if ($(this).closest('.file-details').length) {
          var upload_id = $(this).attr('name');
          upload_id = upload_id.substr(0, upload_id.lastIndexOf('_del_'));
          return FormValidator.check($(this).closest('form').find('input[name=' + upload_id + ']'));
        }
      }
    );

    /* Finally the live query stuff! */
    Pagesmith.On.load( '.logic', function () {
      if (!$(this).is('form')) {
        $(this).closest('form').addClass('logic');
      }
    });
  });

  Pagesmith.On.load(
    'form.logic', function () { return FormValidator.check_logic($(this)); }
  ).load(
    'form.check :input', function () { return FormValidator.check($(this)); }
  ).load(
    'label', function () { return FormValidator.push_label($(this)); }
  );

  /* Multi-select... */
  $('body').on('click','.add_entry',function () {
    var inputs = $(this).prevAll('select'),nd,sel_i,sel_t,sel_v,in_t,in_node;
    if( inputs.length ) {
      nd = inputs.eq(0);
      sel_i = nd.prop('selectedIndex');
      sel_t = $.trim(nd.find('option').eq([sel_i]).prop('text'));
      sel_v = $.trim(nd.find('option').eq([sel_i]).prop('value'));
      if( typeof(sel_v) === 'undefined' ) {
        sel_v = sel_t;
      }
      if( sel_v !== '' ) {
        if(  ! nd.parent().find('span.close_box').filter(function(){ return $.trim($(this).text()) === sel_t; }).length ) {
          in_node = $('<input />').attr({name:nd.attr('name'),type:'hidden'}).prop( 'value', sel_v );
          nd.parent().append($('<span title="Click to remove" class="close_box" />').text(sel_t).append(in_node) );
        }
        nd[0].selectedIndex = 0;
        FormValidator.check(nd);
      }
      return;
    }
    inputs = $(this).prevAll('input');
    if( inputs.length ) {
      nd = inputs.eq(0);
      in_t = $.trim(nd.val());
      if( in_t !== '' ) {
        if( ! nd.parent().find('span.close_box').filter(function(){ return $.trim($(this).text()) === in_t; }).length ) {
          in_node = $('<input />').attr({name:nd.attr('name'),type:'hidden'}).prop( 'value', in_t );
          nd.parent().append($('<span title="Click to remove" class="close_box" />').text(in_t).append(in_node) );
        }
        nd.val('');
        FormValidator.check(nd);
      }
    }
    return;
  });

  /* This method then removes the entry */
  $('body').on('click','.close_box',function() {
    var Z = $(this).closest('dd').find(':input').eq(0);
    $(this).remove();
    FormValidator.check( Z.eq(0) );
  });

  $(window).on('load',function() {
    window.setTimeout(function(){
      $('form.check :input').each(function () {
        FormValidator.check($(this));
      });
    },100 );
  });
}(jQuery));
/* jshint +W074 */
