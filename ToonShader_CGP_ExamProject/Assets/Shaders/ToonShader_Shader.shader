Shader "Custom/ToonShader_Shader" { // defines the name of the shader, and location folder; i.e. "Custom"
	Properties{ //Properties to be used and recognized by Unity; their name in unity, values, their starting value etc.
		_Color("Diffuse Color", Color) = (1,1,1,1)
		_UnlitColor("Unlit Diffuse Color", Color) = (0.5,0.5,0.5,1)
		_UnlitColorPower("Strength of Unlit", Range(0.1,2)) = 1
		_DiffuseThreshold1("Threshold: Diffuse C1", Range(0,1)) = 0.1
		_DiffuseThreshold2("Threshold: Diffuse C2", Range(0,1)) = 0.1
		_OutlineColor("Outline Color", Color) = (0,0,0,1)
		_LitOutline("Lit Outline Thickness", Range(0,1)) = 0.1
		_UnlitOutline("Unlit Outline Thickness", Range(0,1)) = 0.4
		_DiffuseReflectionPower("Diffuse Reflec Intensity", Range(0,2)) = 1.0
		_SpecColor("Specular Color", Color) = (1,1,1,1)
		_Shininess("Shininess", Range(0.1, 50)) = 10
		_SpecReflectionPower("Spec Reflec Intensity", Range(0,2)) = 1.0
		_HighlightThreshold("Theshold Spec High", Range(0.3,1.1)) = 0.7
	}
		SubShader{ // Unity chooses the subshader that fits the GPU best
			Pass{ // some shaders require multiple passes
			Tags{ "LightMode" = "ForwardBase" } // pass for ambient light and first light source

			CGPROGRAM //Start of Unity CG shader

	#pragma vertex vert // this specifies the vert function as the vertex shader 
	#pragma fragment frag // this specifies the frag function as the fragment shader
	#include "UnityCG.cginc"

	//Specified properties
	uniform float4 _LightColor0;
	uniform float4 _Color;
	uniform float4 _UnlitColor;
	uniform float _DiffuseThreshold1;
	uniform float _DiffuseThreshold2;
	uniform float4 _OutlineColor;
	uniform float _LitOutline;
	uniform float _UnlitOutline;
	uniform float4 _SpecColor;
	uniform float _Shininess;
	uniform float _UnlitColorPower;
	uniform float _SpecReflectionPower;
	uniform float _DiffuseReflectionPower;
	uniform float _HighlightThreshold;

	//Vertex Input Parameters
	struct vertexInput {
		float4 vertex : POSITION; // position (in object coordinates, i.e. local or model coordinates)
		float3 normal : NORMAL;// surface normal vector (in object coordinates; usually normalized to unit length)
	};

	//Vertex Output Parameters
	struct vertexOutput { 
		float4 pos : SV_POSITION; //vertex output parameter with semantic SV_POSITION (used in projection transformation for Clip Coordinates)							!
		float4 posWorld : TEXCOORD0; // 0th set of texture coordinates (a.k.a. “UV”; between 0 and 1) 
		float3 normalDir : TEXCOORD1; // 1st  ---||---
	};

	//////////// VERTEX SHADER ////////////
	vertexOutput vert(vertexInput input) //takes the vertexInput struct as argument to ensure matching semantics (I think?)
	{
		vertexOutput output; //Defining the struct for the output; no need for specifying the 'struct' as this is done automatically.

		float4x4 modelMatrix = unity_ObjectToWorld; //Define the 4x4 transformation 'modelMatrix' for defining world position.											!
		float4x4 modelMatrixInverse = unity_WorldToObject; //Used as the inverse of the above specified; used to calculate the normal direction							!

		output.posWorld = mul(modelMatrix, input.vertex); //Calculate the position in world space by multiplying the modelMatrix with the input vertices of the object. !
		output.normalDir = normalize(mul(float4(input.normal, 0.0), modelMatrixInverse).xyz); //Calculate the normalized direction of the vectors of the object.		!
		output.pos = mul(UNITY_MATRIX_MVP, input.vertex); //transformation of input.vertex from object coordinates to world coordinates;
		return output; //Returns final output from the struct; can only return one value.
	}

	//////////// FRAGMENT SHADER ////////////
	float4 frag(vertexOutput input) : COLOR //Using the structure as an argument for the fragment shader to make sure the semantics match. 
	{

		float3 normalDirection = normalize(input.normalDir); //Normalize the direction of the object vectors															?
		float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz); //Normalize the view direction
		float3 lightDirection; //float3 for holding the vector direction of the light
		float attenuation; //float value for holding the attenuation of light

		//https://en.wikibooks.org/wiki/Cg_Programming/Unity/Diffuse_Reflection
		//Caluclate Attenuation and light direction: Used to determine the decay (rate) of light and direction
		//_WorldSpaceLightPos0 is a Unity specific uniform that gives the direction of a directional light or the position in world space
		//in the event of a point- or spotlight. 
		if (0.0 == _WorldSpaceLightPos0.w)
			//The 4th component of the _WorldSpaceLightPos0.w can be either 1 or 0; and this can be used to determine whether it is a
			//directional light or something else. A directional light will have 0 in it's w'th component while point and spot have 1, 
			//and so we ask if it is 0 to determine if we have a directional light.
		{
			//As directional light has no attenuation (i.e. it imitates the sun which have VERY little due to the range), 
			//we set the value to 1 (i.e. no attenuation)
			attenuation = 1.0;
			lightDirection = normalize(_WorldSpaceLightPos0.xyz); //Normalizes the direction of the light so we know where it is coming from. 
		}
		// If we do not have a directional light, we must be having a point- or spotlight (I.e. w'th component of _WorldSpaceLightPos0 is greater than
		// 0.0; it is 1). If this is the case, then we acknowledge that we now have the position, and not direction, of the light.
		else 
		{
			//Compute the preliminary calculations to determine distance and light direction
			//Subtracting the position of the light with the position of the object, will yield the vector between them. 
			float3 vertexToLightSource = _WorldSpaceLightPos0.xyz - input.posWorld.xyz;
			
			//As our "vertexToLightSource" is the vector going from the lightsource to the mesh, we need to know the length to determine distance.
			float distance = length(vertexToLightSource);
			//As attenuation is given by the original value divided by the distance, we can now compute the attenuation. Realistically, this would imply a quadratic decay
			//of the light (i.e. divided by 4 times the distance). This would essentially mean, that we would have very high intensity levels before we begin to see anything.
			//It is too extreme for us, so instead we use a linear decay rate: the attenuation divided by the distance.
			attenuation = 1.0 / distance; //Linear decay rate
			lightDirection = normalize(vertexToLightSource); // Normalize the direction of the light.
		}


		//Calculate Ambient Lighting
		//Ambient lighting can be used to light areas in shade if an ambient light exists in a scene. 
		//Unity has a built-in uniform for ambient lighting, which component-wise may be multiplied into
		//the color to determine it depending on the light's color. We will not cover this further. 
		float3 ambientLighting = UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb;


		//Calculate Diffuse Reflection
		//The diffuse reflection is given by the equation: I_diffuse = I_Incoming * K_diffuse * max (0, <N, L>)
		//where I_diffuse is the reflection, I_Incoming is the incoming light, K_diffuse is the constant determined by surface material, and <N, L> is the
		//dot product between the normalized surface normal vector and the normalized direction of incoming light. Essential here is the angle between the
		//two as this is need to determine the reflection. We are computing component-wise for the RGB values of light, to effect these correctly.
		float3 diffuseReflection = (attenuation * _LightColor0.rgb * _Color.rgb * max(0.0, dot(normalDirection, lightDirection)))*_DiffuseReflectionPower;


		// Unlit color for thresholding cuts
		float3 fragmentColor = _UnlitColor.rgb; //I.e. just the fragmentColor so it may be adjusted without directly adjusting the fragmentColor
		// Diffuse illumination with 3 cuts
		// We are thresholding at different levels to determine the colours of the cuts. Depending on the threshold
		// we may adjust the color of the individual cuts. This is, for this assignment, done manually by just
		// multiplying by a slightly lesser number on each cut. 3 cuts total.
		if (attenuation * max(0.0, dot(normalDirection, lightDirection)) >= _DiffuseThreshold1)
		{
			fragmentColor = _LightColor0.rgb * _UnlitColor.rgb * _UnlitColorPower; //Set the color to the original color
		}
		else if (attenuation * max(0.0, dot(normalDirection, lightDirection)) >= _DiffuseThreshold2)
		{
			fragmentColor = _LightColor0.rgb * _UnlitColor.rgb * _UnlitColorPower*0.9; //Set the color to a slightly darker color
		}
		else
		{
			fragmentColor = _LightColor0.rgb * _UnlitColor.rgb * _UnlitColorPower*0.8; //Set the color to a (more) sligthly darker color
		}


		//Specular Highlights and Reflections
		//Initilization of variable to hold the specular reflectivity
		float3 specularReflection;
		if (dot(normalDirection, lightDirection) < 0.0) { 
			// no specular reflection, as the light is not on the right side
			specularReflection = float3(0.0, 0.0, 0.0); //set to 0.
		} else { //Light is on the right side, calculate specular reflection and highlights.
			//Calculates the specular reflectivit; R = 2N(<N, L>)-L  ,  while incorperating attenuation, light- and specular colors.
			//The factors Shininess and SpecReflectionPower helps determine the strength of the reflection. The reason why we are using two
			//is because one is also used in the equation for thresholding.
			specularReflection = (attenuation * _LightColor0.rgb * _SpecColor.rgb * pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess))*_SpecReflectionPower;
			
			//Thesholding: Creating 3 cuts in the specular highlight(s) by thresholding the reflection value (same equation as above).
			//Each cut will lower the intensity just a bit to give it a distinction that that multiple cuts exists from the same light source.
			//The intensity is lowered manually by multiplying with 0.9 and 0.8 respectively, and the threshold is manually set to the same
			//lesser amount for the cuts.
			//pow is a Unity Mathf of "power" and returns a value to the power of another value (in this case, it is raised to the power of the Shininess)
			//
			if (attenuation *  pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess) > _HighlightThreshold) { //Is it above threshold?
				fragmentColor = (_SpecColor.a * _LightColor0.rgb * _SpecColor.rgb + (1.0 - _SpecColor.a) * fragmentColor) + specularReflection;  //Set the color and add reflectivity
			}
			else if (attenuation *  pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess) > _HighlightThreshold - 0.1) {
				fragmentColor = (_SpecColor.a * _LightColor0.rgb * _SpecColor.rgb * 0.9 + (1.0 - _SpecColor.a) * fragmentColor) + specularReflection; //darker color
			}
			else if (attenuation *  pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess) > _HighlightThreshold - 0.2) {
				fragmentColor = (_SpecColor.a * _LightColor0.rgb * _SpecColor.rgb * 0.8 + (1.0 - _SpecColor.a) * fragmentColor) + specularReflection; //even darker color
			}
	}

		//Calculate Outline
		//To display the outlines, we are interpolating between two user set parameters to control the lit and unlit areas. The interpolation between
		//two extremes by a given value X can be done given by the built-in lerp function Lerp(a, b, x), where a is the start, b is the end and x
		//is the interpolation value. Thus we are interpolating based on our vector direction of the light.
		//Once the interpolation value is determined, we may threshold this against the vector dot product of viewing direction and normal direction.
		//This vector dot product in turn yields the silhouettes of the object, which then may be outlined with the OutlineColor.
		if (dot(normalDirection, viewDirection) < lerp(_UnlitOutline, _LitOutline, max(0.0, dot(normalDirection, lightDirection)))) //thresholding based on interpolation
		{
			//Set the color of the outline (subtracted with the specularReflection, diffuseReflection and ambientLighting as these will also influence the outline color)
			fragmentColor = _LightColor0.rgb * (_OutlineColor.rgb - specularReflection - diffuseReflection - ambientLighting);
		}

		//Finally we return the color based on the struct. Before returning the final result, we add the diffuseReflection and ambientlight
		//(if an ambient light exists) to calculate the final color of the pixel occupying the object with the shader script attached.
		return float4(fragmentColor + diffuseReflection + ambientLighting, 1.0);
	}
		ENDCG //End Unity CG shader
	}
	}
		Fallback "Specular" //Built-in fallback shader "Specular" in the event Unity does not use the "Forward Rendering Path"
}
