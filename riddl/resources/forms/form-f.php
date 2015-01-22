<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
    <title>Form Deluxe</title>
    <link href="form.css" rel="stylesheet" />
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/2.1.3/jquery.min.js"></script> 
    <script type="text/javascript">
      $(document).ready(function(){
      });

      function do_it(url,wlurl,baseurl) { //{{{
        $.ajax({
          type: "PUT",
          url: url,
          data: "answer=" +$("input[name='ok']:checked").val(),
          success: function() {
            $.ajax({
              type: "DELETE",
              url: wlurl,
              success: function() {
                console.log("Everything went fine");
                window.location.href = baseurl;
              },
              error: function(a,b,c){
                console.log("Error while deleting. Put was successful though");
              }
            });
          },
          error: function(a,b,c) {
            console.log("Error while putting to CPEE");
          }
        });
      } //}}}
    </script>

  </head>
  <body>
    <div id="check">
      <?php
            // Allow from any origin //{{{
        if (isset($_SERVER['HTTP_ORIGIN'])) {
            header("Access-Control-Allow-Origin: {$_SERVER['HTTP_ORIGIN']}");
            header('Access-Control-Allow-Credentials: true');
            header('Access-Control-Max-Age: 86400');    // cache for 1 day
        }

        // Access-Control headers are received during OPTIONS requests
        if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {

            if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_METHOD']))
                header("Access-Control-Allow-Methods: GET, POST, OPTIONS");         

            if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']))
                header("Access-Control-Allow-Headers:        {$_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']}");

            exit(0);
        } //}}}

        $bla = isset($_POST['parameters']) ? json_decode($_POST['parameters']) : null;
        echo '<p class="p_text"> Die Schadenssummer beträgt ' . (empty($bla) ? "unbekannt" : $bla[0]->value) . ' Euro</p>';
        echo '<p class="p_text"> Laut unserem Techniker ist dieses Auto ' . (empty($bla) ? "nicht bekannt" : $bla[1]->value) . '. </p>';
      ?>
      <table>
        <tr>
          <td>
            <input class ="rbt" type=radio name="ok" id="radiook" value="ok" checked/> OK
            <input class ="rbt" type=radio name="ok" id="radionok" value="nok" /> Nicht OK
          </td>
          <td>
            <?php
              echo "<input type= 'button' onclick = 'do_it(\"" . (isset($_POST['url']) ? $_POST['url']:"null") . "\",\"" . (isset($_POST['wlurl']) ? $_POST['wlurl'] : "null") . "\",\"" . (isset($_POST['baseurl']) ? $_POST['baseurl']:"null") . "\")' id=\"butt\" value=\"absenden\"/"
            ?>
          </td>
        </tr>
      </table>
    </div>
  </body>
</html>
