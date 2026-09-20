package com.example.recorder;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.util.ArrayList;
import java.util.List;

import org.springframework.stereotype.Service;

/**
 * Service layer is where all the business logic lies
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class Utilities {

    public static void thrashGarbageCollector() {
        for (int j=0; j < 2; j++) {
            List<Object> garbageList = new ArrayList<>();
            for (int i = 0; i < 100000; i++) {
                // Each iteration creates a new, small object
                garbageList.add(new byte[1024]); // Allocate 1KB byte array
                log.info("allocating temp trade record");
            }
            System.gc();
        }
    }
}
