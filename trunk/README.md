pagesmith-core
==============

Pagesmith core is the main repository containing the server set up and
code.

Pagesmith
=========

Pagesmith is the loose framework developed by the Wellcome Trust
Sanger Institute web team to manage the http://www.sanger.ac.uk/
and a number of other smaller websites:

**Pagesmith offers:**
* Simple XHTML page templates;
* JavaScript and CSS libraries to give a consistent look and feel;
* JavaScript libraries to simplify dynamic webpage construction,
  including AJAX content, JSON based table, tab and list generation,
  front-end validation of forms
* Apache2/mod_perl libraries to handle:
    * page generation and template management;
    * simplify the production of in-line components (when JavaScript/CSS
      just wont quite cut it);
    * make dynamic page generation easy;
    * handling configuration files, database queries, sessions;
* Simple (extensible) user authentication model;
* Ability to wrap pages written in a number of other languages, or
  served on other servers, e.g. PHP, Java (via mod_jk) and Ruby
* Developer tools built in:
    * to view errors within the webpage;
    * to "group" errors in the error logs;
    * to manage staging and publishing via SVN hooks;
    * to ensure code: HTML, JavaScript and perl matches common standards,
    * so it is easier to maintain in the long term;
* Automatic web page optimisation - to minify and merge CSS and
  JavaScript libraries
* Built in page, action and component caching (for live servers)
* Utilities to optimise images, manage caches etc.

