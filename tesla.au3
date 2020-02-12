#NoTrayIcon
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>
#include <TrayConstants.au3> ; Required for the $TRAY_ICONSTATE_SHOW constant.
#include <json.au3> ; https://github.com/J2TEAM/AutoIt-Imgur-UDF/blob/master/include/JSON.au3

Opt("TrayMenuMode", 3) ; The default tray menu items will not be shown and items are not checked when selected. These are options 1 and 2 for TrayMenuMode.

Const $HTTP_STATUS_OK = 200
Global $vehicle_menu_array[0];

$host = "https://owner-api.teslamotors.com"
$rest = $host & "/api/1/"

; If auth token is not available, prompt for it
If IniRead("config.ini", "auth", "access_token", -1) = -1 Then
   GetAuth()
EndIf

; If vehicles have not been fetched, fetch them
If IniRead("config.ini", "vehicles", "count", -1) <= 0 Then
   GetVehicles()
   TrayTip(0, "", "Right click on this icon to access Tesla Menu")
EndIf

#Region Create Tray
$iAuthentication = TrayCreateMenu("Authentication") ; Create a tray menu sub menu with two sub items.
$idGetAuthToken = TrayCreateItem("Get authentication token", $iAuthentication)
$idRefreshToken = TrayCreateItem("Refresh token", $iAuthentication)
TrayCreateItem("") ; Create a separator line.

$iCommands = TrayCreateMenu("Commands")
$idWake = TrayCreateItem("Wake", $iCommands)
$iClimate = TrayCreateMenu("Climate", $iCommands)
$idClimate_Start = TrayCreateItem("Climate Start", $iClimate)
$idClimate_Stop = TrayCreateItem("Climate Stop", $iClimate)
TrayCreateItem("") ; Create a separator line.

$idGetVehicles = TrayCreateItem("Fetch Vehicle Info")
TrayCreateItem("") ; Create a separator line.

CreateVehiclesTray()
TrayCreateItem("") ; Create a separator line.

$idExit = TrayCreateItem("Exit")

TraySetState($TRAY_ICONSTATE_SHOW) ; Show the tray menu.
#EndRegion

While 1
   $msg = TrayGetMsg()
   Switch $msg
	  Case $idWake
		 Wake(GetSelectedVehicleId())
	  Case $idClimate_Start
		 StartClimateControl(GetSelectedVehicleId())
	  Case $idClimate_Stop
		 StopClimateControl(GetSelectedVehicleId())
	  Case $idGetAuthToken
		 GetAuth()
	  Case $idRefreshToken
		 RefreshToken()
	  Case $idGetVehicles
		 GetVehicles()
	  Case $idExit ; Exit the loop.
		  ExitLoop
   EndSwitch
   ; check for switching between vehicles
   For $i = 0 To UBound($vehicle_menu_array) - 1
	  If $msg = $vehicle_menu_array[$i] Then
		 SelectVehicle($i)
	  EndIf
   Next
   Sleep(10)
WEnd

Func CreateVehiclesTray()
   ; clear existing vehicles
   For $i = 0 To UBound($vehicle_menu_array) - 1
	  TrayItemDelete($vehicle_menu_array[$i])
   Next

   $ids = IniRead("config.ini", "vehicles", "ids", "")
   $ids = StringSplit($ids, ",")
   ReDim $vehicle_menu_array[$ids[0]]
   For $i = 1 To $ids[0]
	  $name = IniRead("config.ini", $ids[$i], "display_name", "")
	  $selected = IniRead("config.ini", $ids[$i], "selected", "")
	  $vehicle_menu_array[$i - 1] = TrayCreateItem($name, -1, $i + 5)
	  If $selected = "true" Then
		 TrayItemSetState($vehicle_menu_array[$i - 1], $TRAY_CHECKED)
	  EndIf
   Next
EndFunc

Func SelectVehicle($index)
   $ids = IniRead("config.ini", "vehicles", "ids", "")
   $ids = StringSplit($ids, ",")
   For $i = 1 To $ids[0]
	  If $index = $i - 1 Then
		 IniWrite("config.ini", $ids[$i], "selected", "true")
	  Else
		 IniWrite("config.ini", $ids[$i], "selected", "false")
	  EndIf
   Next
   CreateVehiclesTray()
EndFunc

Func GetSelectedVehicleId()
   $ids = IniRead("config.ini", "vehicles", "ids", "")
   $ids = StringSplit($ids, ",")
   For $i = 1 To $ids[0]
	  If IniRead("config.ini", $ids[$i], "selected","") = "true" Then
		 Return $ids[$i]
	  EndIf
   Next
   MsgBox(0, "Error", "Must Fetch Vehicle Info first.")
   return -2
EndFunc

Func Wake($id)
   $command = "/wake_up"

   $url = $rest & "vehicles/" & $id & $command
   $response = HttpPost($URL)
   MsgBox(0, "Response", $response)
   return $response
EndFunc

Func StartClimateControl($id)
   $command = "/command/auto_conditioning_start"

   $url = $rest & "vehicles/" & $id & $command
   $response = HttpPost($URL)
   MsgBox(0, "Response", $response)
   return $response
EndFunc

Func StopClimateControl($id)
   $command = "/command/auto_conditioning_stop"

   $url = $rest & "vehicles/" & $id & $command
   $response = HttpPost($URL)
   MsgBox(0, "Response", $response)
   return $response
EndFunc

Func GetAuth()
   $command = "/oauth/token"
   $url = $host & $command

   $client_id = IniRead("config.ini", "auth", "client_id", -1)
   If ($client_id < 0) Then
	  $client_id = InputBox("Client ID", "Enter Client ID (see pastebin.com/YiLPDggh)")
	  IniWrite("config.ini", "auth", "client_id", $client_id)
   EndIf

   $client_secret = IniRead("config.ini", "auth", "client_secret", -1)
   If ($client_secret < 0) Then
	  $client_secret = InputBox("Client Secret", "Enter Client Secret (see pastebin.com/YiLPDggh)")
	  IniWrite("config.ini", "auth", "client_secret", $client_secret)
   EndIf

   $email = InputBox("Tesla OAuth", "Enter your Tesla.com email (never stored)")
   $pass = InputBox("Tesla OAuth","Enter your Tesla.com password (never stored)", "", "*")


   $sData = '{ ' & _
	 '"grant_type": "password",' & _
	 '"client_id": "' & $client_id & '",' & _
	 '"client_secret": "' & $client_secret & '",' & _
	 '"email": "' & $email & '",' & _
	 '"password": "' & $pass & '"' & _
   '}'

   $response = HttpPost($URL, $sData)
   $jsonobj = json_decode($response)

   $access_token = json_get($jsonobj, '.access_token')
   IniWrite("config.ini", "auth", "access_token", $access_token)

   $refresh_token = json_get($jsonobj, '.refresh_token')
   IniWrite("config.ini", "auth", "refresh_token", $refresh_token)

   $created_at = json_get($jsonobj, '.created_at')
   IniWrite("config.ini", "auth", "created_at", $created_at)

   $expires_in = json_get($jsonobj, '.expires_in')
   IniWrite("config.ini", "auth", "expires_in", $expires_in)

EndFunc

Func RefreshToken()
   MsgBox(0, "TODO", "Not coded yet")
EndFunc

Func GetVehicles()
   $command = "/vehicles"
   $url = $rest & $command
   $response = HttpGet($url)
   $jsonobj = json_decode($response)
   $count = json_get($jsonobj, '.count')
   IniWrite("config.ini", "vehicles", "count", $count)
   $ids = ""
   For $i = 0 To $count - 1
	  $id = json_get($jsonobj, '.response[' & $i & '].id')
	  If $i = $count - 1 Then
		 $ids &= $id
		 IniWrite("config.ini", $id, "selected", "true")
	  Else
		 $ids &= $id & ","
		 IniWrite("config.ini", $id, "selected", "false")
	  EndIf
	  IniWrite("config.ini",$id, "vehicle_id", json_get($jsonobj, '.response[' & $i & '].vehicle_id'))
	  IniWrite("config.ini",$id, "display_name", json_get($jsonobj, '.response[' & $i & '].display_name'))
	  IniWrite("config.ini",$id, "id_s", json_get($jsonobj, '.response[' & $i & '].id_s'))
   Next

   IniWrite("config.ini", "vehicles", "ids", $ids)
   CreateVehiclesTray()
EndFunc

Func HttpPost($sURL, $sData = "")
   Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")

   ConsoleWrite($sURL & @CRLF)
   $oHTTP.Open("POST", $sURL, False)
   If (@error) Then ConsoleWriteError("Open" & @CRLF)
   If (@error) Then Return SetError(1, 0, 0)

   $oHTTP.SetRequestHeader("Content-Type", "application/json")
   $access_token = IniRead("config.ini", "auth", "access_token", null);
   If $access_token <> null Then
	  $oHTTP.SetRequestHeader("Authorization", "Bearer " & $access_token)
   ElseIf $sUrl <> "/oauth/token" Then
	  MsgBox(0,"Error", "Must get authentication token first.")
	  Return
   EndIf
   $oHTTP.SetRequestHeader("User-Agent", "Custom Owner API call")
   $oHTTP.SetRequestHeader("Accept", "application/json")

   $oHTTP.Send($sData)
   If (@error) Then ConsoleWriteError("Send" & @CRLF)
   If (@error) Then Return SetError(2, 0, 0)

   ConsoleWrite("HTTP Status: " & $oHTTP.Status & @CRLF)
   If ($oHTTP.Status <> $HTTP_STATUS_OK) Then Return SetError(3, 0, 0)

   Return SetError(0, 0, $oHTTP.ResponseText)
EndFunc

Func HttpGet($sURL, $sData = "")
   Local $oHTTP = ObjCreate("WinHttp.WinHttpRequest.5.1")

   $oHTTP.Open("GET", $sURL & "?" & $sData, False)
   If (@error) Then Return SetError(1, 0, 0)

   $access_token = IniRead("config.ini", "auth", "access_token", null);
   If $access_token <> null Then
	  $oHTTP.SetRequestHeader("Authorization", "Bearer " & $access_token)
   ElseIf $sUrl <> "/oauth/token" Then
	  MsgBox(0,"Error", "Must get authentication token first.")
	  Return
   EndIf

   $oHTTP.Send()
   If (@error) Then Return SetError(2, 0, 0)

   If ($oHTTP.Status <> $HTTP_STATUS_OK) Then Return SetError(3, 0, 0)

   Return SetError(0, 0, $oHTTP.ResponseText)
EndFunc