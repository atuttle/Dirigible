<cfcomponent>

	<cfset variables.appKey = "" />
	<cfset variables.appMasterSecret = "" />
	
	<cfset variables.devices = structNew()/>
	<cfset variables.devices.android = arrayNew(1) />
	<cfset variables.devices.apple = arrayNew(1) />
	<cfset variables.baseURL = "https://go.urbanairship.com/" />

	<!--- public methods; API --->

	<cffunction name="init">
		<cfargument name="appKey" required="false" />
		<cfargument name="appMasterSecret" required="false" />
		<cfargument name="JSONUtil" default="#createObject('component', 'com.JSONUtil')#" />

		<cfif structKeyExists(arguments, "appKey")>
			<cfset variables.appKey = arguments.appKey />
		</cfif>
		<cfif structKeyExists(arguments, "appMasterSecret")>
			<cfset variables.appMasterSecret = arguments.appMasterSecret />
		</cfif>

		<cfset variables.jsonUtil = arguments.JSONUtil />

		<cfreturn this />
	</cffunction>

	<cffunction name="setAppKey" access="public">
		<cfargument name="appKey" required="true" />
		<cfset variables.appKey = arguments.appKey />
	</cffunction>

	<cffunction name="setAppMasterSecret" access="public">
		<cfargument name="appMasterSecret" required="true" />
		<cfset variables.appMasterSecret = arguments.appMasterSecret />
	</cffunction>

	<cffunction name="setJSONUtil" access="public">
		<cfargument name="JSONUtil" required="true" />
		<cfset variables.jsonUtil = arguments.JSONUtil />
	</cffunction>

	<cffunction name="refreshDevices" access="public">
		<cfdump var="#refreshAppleDevices()#" />
		<cfdump var="#refreshAndroidDevices()#" />
	</cffunction>
	
	<cffunction name="getDevices">
		<cfreturn variables.devices />
	</cffunction>

	<cffunction name="broadcast">
		<cfargument name="msg">
		<cfset var payload = "" />
		<cfsavecontent variable="payload"><cfoutput>
			{
				"aps": {
					"alert":"#escapeStringForJson( msg )#"
				},
				"android": {
					"alert":"#escapeStringForJson( msg )#"
				}
				
			}
		</cfoutput></cfsavecontent>
		<cfset apiCall("POST", "/api/push/broadcast/", compressJsonWhitespace( payload )) />
	</cffunction>

	<cffunction name="push">
		<cfargument name="deviceTokens" default="#arrayNew(1)#" hint="iOS" />
		<cfargument name="deviceTokens_exclude" default="#arrayNew(1)#" hint="iOS" />
		<cfargument name="apids" default="#arrayNew(1)#" hint="Android" />
		<cfargument name="tags" default="#arrayNew(1)#" hint="Both iOS and Android" />
		<cfargument name="aliases" default="#arrayNew(1)#" hint="Both iOS and Android" />
		<cfargument name="alert" default="" hint="Both iOS and Android" />
		<cfargument name="badge" default="" hint="iOS ONLY; http://urbanairship.com/docs/push.html##autobadge (remove one of the ##'s so the URL will work)" />
		<cfargument name="sound" default="silent" hint="iOS ONLY; http://urbanairship.com/docs/push.html##sounds (remove one of the ##'s so the URL will work)" />
		<cfargument name="extra" default="#structNew()#" hint="Android ONLY" />
		<!--- TODO: scheduled pushes --->
		<cfset var payload = arrayNew(1) />
		<cfset var i = 0 />
		
		<!---
			Construct new payload
		--->
		
		<!--- iOS --->
		<cfif arrayLen(arguments.deviceTokens) or arrayLen(arguments.tags) or arrayLen(arguments.aliases)>
			<cfset i++ />
			<cfset payload[i] = {} />
			<!--- add device tokens --->
			<cfif arrayLen(arguments.deviceTokens)>
				<cfset payload[i]["device_tokens"] = arguments.deviceTokens />
			</cfif>
			<!--- add device token exclusions --->
			<cfif arrayLen(arguments.deviceTokens_exclude)>
				<cfset payload[i]["exclude_tokens"] = arguments.deviceTokens_exclude />
			</cfif>
			<!--- add tags --->
			<cfif arrayLen(arguments.tags)>
				<cfset payload[i]["tags"] = arguments.tags />
			</cfif>
			<!--- add aliases --->
			<cfif arrayLen(arguments.deviceTokens)>
				<cfset payload[i]["aliases"] = arguments.aliases />
			</cfif>
			<cfset payload[i]["aps"] = {} />
			<cfif arguments.badge neq "">
				<cfset payload[i]["aps"]["badge"] = javacast("string", arguments.badge) />
			</cfif>
			<cfif arguments.sound neq "silent">
				<cfset payload[i]["aps"]["sound"] = arguments.sound />
			</cfif>
			<cfif arguments.alert neq "">
				<cfset payload[i]["aps"]["alert"] = arguments.alert />
			</cfif>
		</cfif>
		
		<!--- Android --->
		<cfif arrayLen(arguments.apids) or arrayLen(arguments.tags) or arrayLen(arguments.aliases)>
			<cfset i++ />
			<cfset payload[i] = {} />
			<!--- add devices --->
			<cfif arrayLen(arguments.apids)>
				<cfset payload[i]["apids"] = arguments.apids />
			</cfif>
			<!--- add tags --->
			<cfif arrayLen(arguments.tags)>
				<cfset payload[i]["tags"] = arguments.tags />
			</cfif>
			<!--- add aliases --->
			<cfif arrayLen(arguments.deviceTokens)>
				<cfset payload[i]["aliases"] = arguments.aliases />
			</cfif>

			<cfset payload[i]["android"] = {} />
			<cfif arguments.alert neq "">
				<cfset payload[i]["android"]["alert"] = arguments.alert />
			</cfif>
			<cfif !structIsEmpty(arguments.extra)>
				<cfset payload[i]["android"]["extra"] = duplicate(arguments.extra) />
			</cfif>
		</cfif>

		<!--- serialize payload --->
		<cfset payload = variables.jsonUtil.serializeToJson(payload, false, true) />

		<cfset apiCall("POST", "/api/push/", payload) />
	</cffunction>

	<!--- internals --->

	<cffunction name="getBaseURL" access="private">
		<cfreturn variables.baseURL />
	</cffunction>

	<cffunction name="escapeStringForJson" output="false" access="private">
		<cfargument name="str" />
		<cfreturn trim(replaceList(arguments.str, '",'',\,#chr(13)#,#chr(10)#,#chr(9)#', '\",\'',\\,\r,\n,\t')) />
	</cffunction>
	
	<cffunction name="compressJsonWhitespace" access="private">
		<cfargument name="str" />
		<cfreturn trim(rereplace(str, "\s+", " ", "ALL")) />
	</cffunction>

	<cffunction name="refreshAppleDevices" access="private">
		<cfset var result = apiCall("GET","/api/device_tokens/") />
		<cfreturn deserializeJson( result.fileContent.toString() ) />
	</cffunction>

	<cffunction name="refreshAndroidDevices" access="private">
		<cfset var result = apiCall("GET", "/api/apids/") />
		<cfreturn deserializeJson( result.fileContent.toString() ) />
	</cffunction>

	<cffunction name="apiCall" access="private">
		<cfargument name="method" />
		<cfargument name="uri" />
		<cfargument name="body" />

		<cfif variables.appKey eq "">
			<cfthrow message="You have not set your Application Key. Pass argument `appKey` to init() or use `setAppKey()`">
		</cfif>

		<cfif variables.appMasterSecret eq "">
			<cfthrow message="You have not set your Application Master Secret. Pass argument `appMasterSecret` to init() or use `setAppMasterSecret()`">
		</cfif>

		<cfhttp 
			method="#arguments.method#" 
			url="#getBaseURL()##arguments.uri#" 
			username="#variables.appKey#"
			password="#variables.appMasterSecret#">
			<cfif structKeyExists(arguments, "body") and len(arguments.body) neq 0>
				<cfhttpparam type="header" name="Content-Type" value="application/json; charset=UTF-8" />
				<cfhttpparam type="body" value="#arguments.body#" />
			</cfif>
		</cfhttp>

		<cfif cfhttp.statusCode neq "200 OK">
			<cfthrow message="Failure response from Urban Airship API: #listFirst(cfhttp.statusCode, ' ')#" detail="#cfhttp.fileContent.toString()#">
		</cfif>

		<cfreturn cfhttp />
	</cffunction>

</cfcomponent>
