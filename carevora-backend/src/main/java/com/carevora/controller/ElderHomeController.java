package com.carevora.controller;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.auth.FacilityAccessRequest;
import com.carevora.dto.elderhome.ElderHomeRequest;
import com.carevora.dto.elderhome.ElderHomeResponse;
import com.carevora.service.ElderHomeService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/elder-homes")
@RequiredArgsConstructor
@Tag(name = "Elder Homes", description = "Elder care facilities management & assignment")
public class ElderHomeController {

    private final ElderHomeService elderHomeService;

    @GetMapping
    @Operation(summary = "Get all registered active elder homes for selection")
    public ResponseEntity<ApiResponse<List<ElderHomeResponse>>> getAllElderHomes() {
        return ResponseEntity.ok(elderHomeService.getAllElderHomes());
    }

    @GetMapping("/{id}")
    @Operation(summary = "Get elder home details by ID")
    public ResponseEntity<ApiResponse<ElderHomeResponse>> getElderHomeById(@PathVariable Long id) {
        return ResponseEntity.ok(elderHomeService.getElderHomeById(id));
    }

    @GetMapping("/{id}/caregivers")
    @Operation(summary = "Get active caregivers with avatars for an elder home")
    public ResponseEntity<ApiResponse<List<java.util.Map<String, Object>>>> getCaregiversByElderHome(
            @PathVariable Long id
    ) {
        return ResponseEntity.ok(elderHomeService.getCaregiversByElderHomeId(id));
    }

    @PostMapping("/register")
    @Operation(summary = "Register a new elder home facility")
    public ResponseEntity<ApiResponse<ElderHomeResponse>> registerElderHome(
            @Valid @RequestBody ElderHomeRequest request
    ) {
        return ResponseEntity.ok(elderHomeService.registerElderHome(request));
    }

    @PostMapping("/request-access")
    @Operation(summary = "Request facility access and register elder care community")
    public ResponseEntity<ApiResponse<ElderHomeResponse>> requestAccess(
            @Valid @RequestBody FacilityAccessRequest request
    ) {
        return ResponseEntity.ok(elderHomeService.requestFacilityAccess(request));
    }

    @PostMapping("/{homeId}/assign-resident/{residentId}")
    @Operation(summary = "Assign a resident to an elder home facility")
    public ResponseEntity<ApiResponse<ElderHomeResponse>> assignResident(
            @PathVariable Long homeId,
            @PathVariable Long residentId
    ) {
        return ResponseEntity.ok(elderHomeService.assignResident(homeId, residentId));
    }

    @PostMapping("/{homeId}/assign-caregiver/{caregiverId}")
    @Operation(summary = "Assign a caregiver to an elder home facility")
    public ResponseEntity<ApiResponse<ElderHomeResponse>> assignCaregiver(
            @PathVariable Long homeId,
            @PathVariable Long caregiverId
    ) {
        return ResponseEntity.ok(elderHomeService.assignCaregiver(homeId, caregiverId));
    }
}
