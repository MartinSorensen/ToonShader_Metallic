// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/ToonShader_Shader" {
	Properties{
		_Color("Diffuse Color", Color) = (1,1,1,1)
		_UnlitColor("Unlit Diffuse Color", Color) = (0.5,0.5,0.5,1)
		_DiffuseThreshold1("Threshold for Diffuse Cut 1", Range(0,1)) = 0.1
		_DiffuseThreshold2("Threshold for Diffuse Cut 2", Range(0,1)) = 0.1
		_OutlineColor("Outline Color", Color) = (0,0,0,1)
		_LitOutlineThickness("Lit Outline Thickness", Range(0,1)) = 0.1
		_UnlitOutlineThickness("Unlit Outline Thickness", Range(0,1)) = 0.4
		_SpecColor("Specular Color", Color) = (1,1,1,1)
		_Shininess("Shininess", Range(0.1, 50)) = 10
		_UnlitColorPower("Strength of Unlit", Range(1,2)) = 1.1
		_SpecReflectionPower("Spec Reflection intensity", Range(0,2)) = 1.0
		_DiffuseReflectionPower("Diffuse Reflection intensity", Range(0,2)) = 1.0
		_HighlightThreshold("Theshold Spec High", Range(0,1)) = 0.7
		_UpVector("Up Vector", Vector) = (0,1,0,0)
		_UpperHemisphereColor("Upper Hemisphere Color", Color) = (1,1,1,1)
		_LowerHemisphereColor("Lower Hemisphere Color", Color) = (1,1,1,1)

	}
		SubShader{
		Pass{
		Tags{ "LightMode" = "ForwardBase" }
		// pass for ambient light and first light source

		CGPROGRAM

#pragma vertex vert  
#pragma fragment frag 

#include "UnityCG.cginc"
		uniform float4 _LightColor0;
	// color of light source (from "Lighting.cginc")

	// User-specified properties
	uniform float4 _Color;
	uniform float4 _UnlitColor;
	uniform float _DiffuseThreshold1;
	uniform float _DiffuseThreshold2;
	uniform float4 _OutlineColor;
	uniform float _LitOutlineThickness;
	uniform float _UnlitOutlineThickness;
	uniform float4 _SpecColor;
	uniform float _Shininess;
	uniform float _UnlitColorPower;
	uniform float _SpecReflectionPower;
	uniform float _DiffuseReflectionPower;
	uniform float _HighlightThreshold;
	uniform float4 _UpVector;
	uniform float4 _UpperHemisphereColor;
	uniform float4 _LowerHemisphereColor;

	struct vertexInput {
		float4 vertex : POSITION;
		float3 normal : NORMAL;
	};
	struct vertexOutput {
		float4 pos : SV_POSITION;
		float4 posWorld : TEXCOORD0;
		float3 normalDir : TEXCOORD1;
	};

	vertexOutput vert(vertexInput input)
	{
		vertexOutput output;

		float4x4 modelMatrix = unity_ObjectToWorld;
		float4x4 modelMatrixInverse = unity_WorldToObject;

		output.posWorld = mul(modelMatrix, input.vertex);
		output.normalDir = normalize(
			mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
		output.pos = mul(UNITY_MATRIX_MVP, input.vertex);
		return output;
	}

	float4 frag(vertexOutput input) : COLOR
	{
		float3 normalDirection = normalize(input.normalDir);
		float3 upDirection = normalize(_UpVector);
		float sky = 0.5 * (1.0 + dot(upDirection, normalDirection));

		float3 viewDirection = normalize(
			_WorldSpaceCameraPos - input.posWorld.xyz);
		float3 lightDirection;
		float attenuation;

		//Caluclate Attenuation
		if (0.0 == _WorldSpaceLightPos0.w) // directional light?
		{
			attenuation = 1.0; // no attenuation
			lightDirection = normalize(_WorldSpaceLightPos0.xyz);
		}
		else // point or spot light
		{
			float3 vertexToLightSource =
				_WorldSpaceLightPos0.xyz - input.posWorld.xyz;
			float distance = length(vertexToLightSource);
			attenuation = 1.0 / distance; // linear attenuation 
			lightDirection = normalize(vertexToLightSource);
		}

		//Ambient Lighting
		float3 ambientLighting =
			UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb;

		//Calculate Diffuse Reflection
		float3 diffuseReflection = (attenuation * _LightColor0.rgb * _Color.rgb * max(0.0, dot(normalDirection, lightDirection)))*_DiffuseReflectionPower;

		//Calculate SpecularReflection
		float3 specularReflection;
		if (dot(normalDirection, lightDirection) < 0.0)
			// light source on the wrong side?
		{
			specularReflection = float3(0.0, 0.0, 0.0);
			// no specular reflection
		}
		else // light source on the right side
		{
			float3 halfwayDirection = normalize(lightDirection + viewDirection);
			float w = pow(1.0 - max(0.0, dot(halfwayDirection, viewDirection)), 5.0);
			specularReflection = (attenuation * _LightColor0.rgb * lerp(_SpecColor.rgb, float3(1.0, 1.0, 1.0), w) * pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess))*_SpecReflectionPower;
		}
		

		// default: unlit
		float3 fragmentColor = _UnlitColor.rgb;

		// low priority: diffuse illumination
		if (attenuation * max(0.0, dot(normalDirection, lightDirection)) >= _DiffuseThreshold1)
		{
			fragmentColor = _LightColor0.rgb * _UnlitColor.rgb * _UnlitColorPower;
		}
		else if (attenuation * max(0.0, dot(normalDirection, lightDirection)) >= _DiffuseThreshold2) 
		{
			fragmentColor = _LightColor0.rgb * _UnlitColor.rgb * _UnlitColorPower*0.9;
		}
		else
		{
			fragmentColor = _LightColor0.rgb * _UnlitColor.rgb * _UnlitColorPower*0.8;
		}


		// higher priority: outline
		if (dot(viewDirection, normalDirection)
			< lerp(_UnlitOutlineThickness, _LitOutlineThickness,
				max(0.0, dot(normalDirection, lightDirection))))
		{
			fragmentColor = _LightColor0.rgb * (_OutlineColor.rgb - specularReflection - diffuseReflection);
		}

		// highest priority: highlights
		if (dot(normalDirection, lightDirection) > 0.0) {
			if(attenuation *  pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess) > _HighlightThreshold) {
				fragmentColor = ((_SpecColor.a * _LightColor0.rgb * _SpecColor.rgb) + (1.0 - _SpecColor.a) * fragmentColor);
			}
			else if (attenuation *  pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess) > _HighlightThreshold -0.1) {
				fragmentColor = ((_SpecColor.a * _LightColor0.rgb * _SpecColor.rgb) * 0.9 + (1.0 - _SpecColor.a) * fragmentColor);
			}
			else if(attenuation *  pow(max(0.0, dot(reflect(-lightDirection, normalDirection), viewDirection)), _Shininess) > _HighlightThreshold -0.2) {
				fragmentColor = ((_SpecColor.a * _LightColor0.rgb * _SpecColor.rgb) * 0.8 + (1.0 - _SpecColor.a) * fragmentColor);
			}
	}

		return float4((sky * _UpperHemisphereColor + (1.0 - sky) * _LowerHemisphereColor) * fragmentColor + diffuseReflection + specularReflection, 1.0);
	}
		ENDCG
	}
	/*
		Pass{
		Tags{ "LightMode" = "ForwardAdd" }
		// pass for additional light sources
		Blend SrcAlpha OneMinusSrcAlpha
		// blend specular highlights over framebuffer

		CGPROGRAM

#pragma vertex vert  
#pragma fragment frag 

#include "UnityCG.cginc"
		uniform float4 _LightColor0;
	// color of light source (from "Lighting.cginc")

	// User-specified properties
	uniform float4 _Color;
	uniform float4 _UnlitColor;
	uniform float _DiffuseThreshold;
	uniform float4 _OutlineColor;
	uniform float _LitOutlineThickness;
	uniform float _UnlitOutlineThickness;
	uniform float4 _SpecColor;
	uniform float _Shininess;

	struct vertexInput {
		float4 vertex : POSITION;
		float3 normal : NORMAL;
	};
	struct vertexOutput {
		float4 pos : SV_POSITION;
		float4 posWorld : TEXCOORD0;
		float3 normalDir : TEXCOORD1;
	};

	vertexOutput vert(vertexInput input)
	{
		vertexOutput output;

		float4x4 modelMatrix = _Object2World;
		float4x4 modelMatrixInverse = _World2Object;

		output.posWorld = mul(modelMatrix, input.vertex);
		output.normalDir = normalize(
			mul(float4(input.normal, 0.0), modelMatrixInverse).rgb);
		output.pos = mul(UNITY_MATRIX_MVP, input.vertex);
		return output;
	}

	float4 frag(vertexOutput input) : COLOR
	{
		float3 normalDirection = normalize(input.normalDir);

		float3 viewDirection = normalize(
			_WorldSpaceCameraPos - input.posWorld.rgb);
		float3 lightDirection;
		float attenuation;

		if (0.0 == _WorldSpaceLightPos0.w) // directional light?
		{
			attenuation = 1.0; // no attenuation
			lightDirection = normalize(_WorldSpaceLightPos0.xyz);
		}
		else // point or spot light
		{
			float3 vertexToLightSource =
				_WorldSpaceLightPos0.xyz - input.posWorld.xyz;
			float distance = length(vertexToLightSource);
			attenuation = 1.0 / distance; // linear attenuation 
			lightDirection = normalize(vertexToLightSource);
		}

		float4 fragmentColor = float4(0.0, 0.0, 0.0, 0.0);
		if (dot(normalDirection, lightDirection) > 0.0
			// light source on the right side?
			&& attenuation *  pow(max(0.0, dot(
				reflect(-lightDirection, normalDirection),
				viewDirection)), _Shininess) > 0.5)
			// more than half highlight intensity? 
		{
			fragmentColor =
				float4(_LightColor0.rgb, 1.0) * _SpecColor;
		}
		return fragmentColor;
	}
		ENDCG
	}*/
	}
		Fallback "Specular"
}
