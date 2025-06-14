#include <iostream>
#include <vector>
#include <string>
#include <algorithm>
#include <iomanip>

using namespace std;

class Student {
public:
    string id;
    string name;
    double processScore; // Điểm quá trình
    double finalScore;   // Điểm cuối kỳ
    double totalScore;   // Điểm tổng kết

    Student(string _id = "", string _name = "", double _processScore = 0.0, double _finalScore = 0.0)
        : id(_id), name(_name), processScore(_processScore), finalScore(_finalScore) {
        totalScore = 0.4 * processScore + 0.6 * finalScore; // Tính điểm tổng kết
    }
};

class StudentManagement {
private:
    vector<Student> students;

public:
    // Thêm hồ sơ sinh viên
    void addStudent() {
        string id, name;
        double processScore, finalScore;
        
        cout << "\nNhap MSSV: ";
        cin >> id;
        cin.ignore();
        cout << "Nhap ho ten: ";
        getline(cin, name);
        cout << "Nhap diem qua trinh: ";
        cin >> processScore;
        cout << "Nhap diem cuoi ky: ";
        cin >> finalScore;
        
        students.push_back(Student(id, name, processScore, finalScore));
        cout << "Them ho so thanh cong!\n";
    }

    // Hiển thị tất cả hồ sơ
    void displayAll() {
        if (students.empty()) {
            cout << "\nKhong co ho so nao!\n";
            return;
        }

        cout << "\nDanh sach sinh vien:\n";
        cout << left << setw(15) << "MSSV" << setw(30) << "Ho ten" 
             << setw(10) << "Qua trinh" << setw(10) << "Cuoi ky" << setw(10) << "Tong ket" << endl;
        cout << string(75, '-') << endl;
        
        for (const auto& student : students) {
            cout << left << setw(15) << student.id 
                 << setw(30) << student.name 
                 << setw(10) << fixed << setprecision(2) << student.processScore
                 << setw(10) << fixed << setprecision(2) << student.finalScore
                 << setw(10) << fixed << setprecision(2) << student.totalScore << endl;
        }
    }

    // Tìm kiếm theo MSSV hoặc tên
    void searchStudent() {
        string query;
        int choice;
        
        cout << "\nTim kiem theo:\n1. MSSV\n2. Ten\nChon: ";
        cin >> choice;
        cin.ignore();
        
        cout << "Nhap thong tin tim kiem: ";
        getline(cin, query);
        
        bool found = false;
        cout << "\nKet qua tim kiem:\n";
        cout << left << setw(15) << "MSSV" << setw(30) << "Ho ten" 
             << setw(10) << "Qua trinh" << setw(10) << "Cuoi ky" << setw(10) << "Tong ket" << endl;
        cout << string(75, '-') << endl;
        
        for (const auto& student : students) {
            if (choice == 1 && student.id == query) {
                cout << left << setw(15) << student.id 
                     << setw(30) << student.name 
                     << setw(10) << fixed << setprecision(2) << student.processScore
                     << setw(10) << fixed << setprecision(2) << student.finalScore
                     << setw(10) << fixed << setprecision(2) << student.totalScore << endl;
                found = true;
            }
            else if (choice == 2 && student.name.find(query) != string::npos) {
                cout << left << setw(15) << student.id 
                     << setw(30) << student.name 
                     << setw(10) << fixed << setprecision(2) << student.processScore
                     << setw(10) << fixed << setprecision(2) << student.finalScore
                     << setw(10) << fixed << setprecision(2) << student.totalScore << endl;
                found = true;
            }
        }
        
        if (!found) {
            cout << "Khong tim thay ket qua!\n";
        }
    }

    // Sắp xếp hồ sơ
    void sortStudents() {
        int choice;
        cout << "\nSap xep theo:\n1. MSSV\n2. Ten\n3. Diem tong ket\nChon: ";
        cin >> choice;
        
        switch (choice) {
            case 1:
                sort(students.begin(), students.end(), 
                    [](const Student& a, const Student& b) { return a.id < b.id; });
                break;
            case 2:
                sort(students.begin(), students.end(), 
                    [](const Student& a, const Student& b) { return a.name < b.name; });
                break;
            case 3:
                sort(students.begin(), students.end(), 
                    [](const Student& a, const Student& b) { return a.totalScore > b.totalScore; });
                break;
            default:
                cout << "Lua chon khong hop le!\n";
                return;
        }
        
        cout << "Da sap xep xong!\n";
    }

    // Hiển thị điểm cao nhất và trung bình
    void displayStats() {
        if (students.empty()) {
            cout << "\nKhong co ho so nao!\n";
            return;
        }

        double highest = students[0].totalScore;
        double sum = 0.0;
        
        for (const auto& student : students) {
            if (student.totalScore > highest) highest = student.totalScore;
            sum += student.totalScore;
        }
        
        cout << "\nThong ke:\n";
        cout << "Diem tong ket cao nhat: " << fixed << setprecision(2) << highest << endl;
        cout << "Diem tong ket trung binh: " << fixed << setprecision(2) << sum / students.size() << endl;
    }
};

int main() {
    StudentManagement system;
    int choice;
    
    do {
        cout << "\n=== Quan Ly Ho So Sinh Vien ===\n";
        cout << "1. Them ho so\n";
        cout << "2. Hien thi tat ca ho so\n";
        cout << "3. Tim kiem sinh vien\n";
        cout << "4. Sap xep ho so\n";
        cout << "5. Thong ke diem\n";
        cout << "0. Thoat\n";
        cout << "Nhap lua chon: ";
        cin >> choice;
        
        switch (choice) {
            case 1:
                system.addStudent();
                break;
            case 2:
                system.displayAll();
                break;
            case 3:
                system.searchStudent();
                break;
            case 4:
                system.sortStudents();
                break;
            case 5:
                system.displayStats();
                break;
            case 0:
                cout << "Tam biet!\n";
                break;
            default:
                cout << "Lua chon khong hop le!\n";
        }
    } while (choice != 0);
    
    return 0;
}