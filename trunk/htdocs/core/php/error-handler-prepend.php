<?php
  function send_error( $msg ) {
    trigger_error( $msg ); 
  }
  error_reporting(E_ALL | E_STRICT);
  function eh( $eno,$estr,$efile,$eline ) {
    $errors = array();
    if( apache_note( 'errors' ) ) {
      $errors = json_decode( apache_note( 'errors' ) );
    }
    $stack_trace = debug_backtrace(1);
    array_shift( $stack_trace );
    array_push( $errors, array(
      'error_no'   => $eno,
      'error_str'  => $estr,
      'error_file' => $efile,
      'error_line' => $eline,
      'stacktrace' => $stack_trace
    ));
    error_reporting( error_reporting() ^ E_WARNING );
    apache_note( 'errors',  json_encode( $errors ) );
    error_reporting( error_reporting() | E_WARNING );
    if( $eno & (E_ERROR|E_USER_ERROR|E_RECOVERABLE_ERROR) ) {
      die( '<p>Script failed with a fatal error</p>' );
    }
  };
  set_error_handler( 'eh', E_ALL );
?>
