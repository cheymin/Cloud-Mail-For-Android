package com.cloudmail.app.model

data class LoginRequest(
    val email: String,
    val password: String
)

data class TokenResponse(
    val token: String
)

data class EmailListRequest(
    val toEmail: String? = null,
    val sendName: String? = null,
    val sendEmail: String? = null,
    val subject: String? = null,
    val content: String? = null,
    val timeSort: String = "desc",
    val type: Int? = null,
    val isDel: Int? = null,
    val num: Int = 1,
    val size: Int = 20
)

data class Email(
    val emailId: Long,
    val sendEmail: String?,
    val sendName: String?,
    val subject: String?,
    val toEmail: String?,
    val toName: String?,
    val createTime: String?,
    val type: Int,
    val content: String?,
    val text: String?,
    val isDel: Int
)

data class AddUserRequest(
    val list: List<UserInfo>
)

data class UserInfo(
    val email: String,
    val password: String? = null,
    val roleName: String? = null
)

data class ApiResponse<T>(
    val code: Int,
    val message: String,
    val data: T?
)