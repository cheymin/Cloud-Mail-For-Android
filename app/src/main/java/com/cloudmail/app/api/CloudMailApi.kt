package com.cloudmail.app.api

import com.cloudmail.app.model.*
import retrofit2.Response
import retrofit2.http.*

interface CloudMailApi {
    
    @POST("api/public/genToken")
    suspend fun generateToken(@Body request: LoginRequest): Response<ApiResponse<TokenResponse>>
    
    @POST("api/public/emailList")
    suspend fun getEmailList(
        @Header("Authorization") authorization: String,
        @Body request: EmailListRequest
    ): Response<ApiResponse<List<Email>>>
    
    @POST("api/public/addUser")
    suspend fun addUser(
        @Header("Authorization") authorization: String,
        @Body request: AddUserRequest
    ): Response<ApiResponse<Void>>
}