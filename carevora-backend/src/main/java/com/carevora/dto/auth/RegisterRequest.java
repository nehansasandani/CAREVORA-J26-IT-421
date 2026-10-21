package com.carevora.dto.auth;

import com.carevora.enums.UserRole;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RegisterRequest {

    @NotBlank(message = "Full name is required")
    private String fullName;

    @NotBlank(message = "Email is required")
    @Email(message = "Please provide a valid email address")
    private String email;

    @NotBlank(message = "Password is required")
    private String password;

    @NotNull(message = "Role is required (CAREGIVER, ELDER, DOCTOR)")
    private UserRole role;

    // Profile picture (Base64 data URL or image URL for CAREGIVER, ELDER, DOCTOR)
    private String avatarUrl;

    // Selected Elder Home (Required for CAREGIVER and ELDER)
    private Long elderHomeId;

    // Optional fields for Elder
    private String roomNumber;
    private Integer age;
    private Integer educationYears;
    private String emergencyContact;

    // Optional fields for Caregiver / Doctor
    private String staffCode;
    private String title;
    private String department;
}
