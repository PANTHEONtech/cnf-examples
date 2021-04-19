package org.onap.ccsdk.cds.blueprintsprocessor.services.execution.scripts

import org.apache.commons.io.IOUtils
import org.apache.http.client.ClientProtocolException
import org.apache.http.client.entity.EntityBuilder
import org.apache.http.client.methods.HttpPut
import org.apache.http.client.methods.HttpUriRequest
import org.apache.http.message.BasicHeader
import org.onap.ccsdk.cds.blueprintsprocessor.core.api.data.ExecutionServiceInput
import org.onap.ccsdk.cds.blueprintsprocessor.functions.resource.resolution.ResourceResolutionComponent
import org.onap.ccsdk.cds.blueprintsprocessor.rest.RestClientProperties
import org.onap.ccsdk.cds.blueprintsprocessor.rest.service.BlueprintWebClientService
import org.onap.ccsdk.cds.blueprintsprocessor.rest.service.RestLoggerService
import org.onap.ccsdk.cds.blueprintsprocessor.services.execution.AbstractScriptComponentFunction
import org.onap.ccsdk.cds.controllerblueprints.core.BlueprintProcessorException
import org.onap.ccsdk.cds.controllerblueprints.core.asJsonNode
import org.onap.ccsdk.cds.controllerblueprints.core.rootFieldsToMap
import org.slf4j.LoggerFactory
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import java.io.IOException
import java.nio.charset.Charset

open class ConfigDeploy : AbstractScriptComponentFunction() {

    private val log = LoggerFactory.getLogger(ConfigDeploy::class.java)!!

    // workflow input parameter names
    private val workflowInputCNFURL = "cnf-rest-url"

    // template resolving (previous step in workflow)
    private val templateResolvingNodeName = "resolve-template"
    private val cnfConfigTemplate = "cnf-config"

    override fun getName(): String {
        return "PantheonCNFConfigDeploy"
    }

    // processNB is the main entry for this script (processing NB input = using NB input to deploy config to CNF)
    override suspend fun processNB(executionRequest: ExecutionServiceInput) {
        log.info("executing Pantheon CNF config deploy script")

        try {
            // get input (from workflow and previous step)
            val cnfRestURL = bluePrintRuntimeService.getInputValue(workflowInputCNFURL)
            val resolvedTemplates = bluePrintRuntimeService.getNodeTemplateOperationOutputValue(
                templateResolvingNodeName,
                "ResourceResolutionComponent",
                operationName,
                ResourceResolutionComponent.OUTPUT_RESOURCE_ASSIGNMENT_PARAMS
            )
            val cnfConfig = resolvedTemplates.rootFieldsToMap()[cnfConfigTemplate]?.asText()
                ?: throw BlueprintProcessorException("Can't get resolved template(CNF configuration) from previous workflow step")

            // apply CNF config
            val api = CNFRestClient(cnfRestURL.asText())
            writeScriptOutputs(api.ApplyConfig(cnfConfig))
        } catch (bpe: BlueprintProcessorException) {
            addError("Failure in config-deployment script: $bpe")
            throw bpe
        }

        log.info("Pantheon CNF config deploy script completed")
    }

    // recoverNB is for recovering state of CNF after problems with executing config deployment (exceptions and problems
    // inside and outside of processNB call)
    override suspend fun recoverNB(runtimeException: RuntimeException, executionRequest: ExecutionServiceInput) {
        log.info("Something went wrong -> Executing CNF Recovery (currently NO recovery implemented for CNF configuration)")
    }

    // writeScriptOutputs writes deployment result to node template attribute used as workflow output
    private fun writeScriptOutputs(result: BlueprintWebClientService.WebClientResponse<String>) {
        if (result.status != 200) {
            addError("Failed to configure CNF due to error response code (${result.status}) from CNF REST API.")
        }
        setAttribute(
            "response-data",
            mutableMapOf<String, String>(
                "CNF-response-code" to (result.status.toString()),
                "CNF-response-message" to (result.body ?: "")
            ).asJsonNode()
        )
    }

    // CNFRestClient is REST client specialized for communication with CNF REST API.
    inner class CNFRestClient(private val restURL: String) {
        private val service: RestClientService // BasicAuthRestClientService

        init {
            // collect all info for REST client service to successfully operate
            var mapOfHeaders = hashMapOf<String, String>()
            mapOfHeaders.put("Content-Type", "application/yaml")
            mapOfHeaders.put("cache-control", " no-cache")
            mapOfHeaders.put("Accept", "application/json")
            // NOTE: use BasicAuthRestClientProperties when basic authentification is needed
            var restClientProperties = RestClientProperties()
            restClientProperties.url = restURL
            restClientProperties.additionalHeaders = mapOfHeaders

            // create REST client service
            this.service = RestClientService(restClientProperties)
        }

        // ApplyConfig uses CNF REST API to configure given configuration for CNF
        fun ApplyConfig(config: String): BlueprintWebClientService.WebClientResponse<String> {
            try {
                return service.put("/configuration", config)
            } catch (e: Exception) {
                throw BlueprintProcessorException("Caught exception trying to apply CNF configuration: ${e.message}", e)
            }
        }
    }
}

// RestClientService is implementation of BlueprintWebClientService that serves as properly configured
// REST client for communicate with CNF. It has no knowledge about the REST API specification of CNF.
class RestClientService(
    private val restClientProperties: RestClientProperties
) : BlueprintWebClientService {

    override fun defaultHeaders(): Map<String, String> {
        return mapOf(
            HttpHeaders.CONTENT_TYPE to MediaType.APPLICATION_JSON_VALUE,
            HttpHeaders.ACCEPT to MediaType.APPLICATION_JSON_VALUE
        )
    }

    override fun host(uri: String): String {
        return restClientProperties.url + uri
    }

    override fun convertToBasicHeaders(headers: Map<String, String>):
        Array<BasicHeader> {
            val customHeaders: MutableMap<String, String> = headers.toMutableMap()
            customHeaders.putAll(verifyAdditionalHeaders(restClientProperties))
            return super.convertToBasicHeaders(customHeaders)
        }

    @Throws(IOException::class, ClientProtocolException::class)
    private fun performHttpCall(httpUriRequest: HttpUriRequest): BlueprintWebClientService.WebClientResponse<String> {
        val httpResponse = httpClient().execute(httpUriRequest)
        val statusCode = httpResponse.statusLine.statusCode
        httpResponse.entity.content.use {
            val body = IOUtils.toString(it, Charset.defaultCharset())
            return BlueprintWebClientService.WebClientResponse(statusCode, body)
        }
    }

    // put calls REST PUT operation for given (url+)path and given payload
    fun put(path: String, payload: String): BlueprintWebClientService.WebClientResponse<String> {
        val convertedHeaders: Array<BasicHeader> = convertToBasicHeaders(defaultHeaders())
        val httpPost = HttpPut(host(path))
        val entity = EntityBuilder.create().setText(payload).build()
        httpPost.setEntity(entity)
        RestLoggerService.httpInvoking(convertedHeaders)
        httpPost.setHeaders(convertedHeaders)
        return performHttpCall(httpPost)
    }
}
