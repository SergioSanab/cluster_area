// =====================================================================
//  area_simpson_omp.cpp  -  Area bajo la curva con OpenMP (memoria compartida)
//  Regla de Simpson 1/3 compuesta, misma funcion que la version MPI:
//
//      f(x) = x * (2 + sen(x)) + 100 * e^(-x/100)       en [a, b]
//      F(x) = x^2 + sen(x) - x*cos(x) - 10000 * e^(-x/100)   (primitiva)
//
//  Uso:
//      ./area_simpson_omp [hilos] [n] [a] [b]
//        hilos = numero de hilos OpenMP   (por defecto, los nucleos disponibles)
//        n     = numero de subintervalos  (por defecto 300000000, se fuerza a par)
//
//  Compilar:  g++ -O2 -fopenmp -o area_simpson_omp area_simpson_omp.cpp -lm
//
//  Salida: bloque legible + una ultima linea "CSV,..." para los scripts.
// =====================================================================

#include <iostream>
#include <iomanip>
#include <cstdlib>
#include <cmath>
#include <vector>
#include <omp.h>

static inline double f(double x)
{
    return x * (2.0 + std::sin(x)) + 100.0 * std::exp(-x / 100.0);
}

static double F(double x)
{
    return x * x + std::sin(x) - x * std::cos(x) - 10000.0 * std::exp(-x / 100.0);
}

int main(int argc, char **argv)
{
    int hilos = omp_get_max_threads();
    long long n = 300000000LL;
    double a = 0.0, b = 1000.0;

    if (argc > 1) hilos = std::atoi(argv[1]);
    if (argc > 2) n     = std::atoll(argv[2]);
    if (argc > 3) a     = std::atof(argv[3]);
    if (argc > 4) b     = std::atof(argv[4]);
    if (hilos < 1) hilos = 1;
    if (n < 2) n = 2;
    if (n % 2 != 0) n++;              // Simpson necesita n par

    omp_set_num_threads(hilos);
    const double h = (b - a) / (double)n;

    std::vector<double> t_hilo(hilos, 0.0);   // tiempo de calculo de cada hilo
    double suma_total = 0.0;

    double t_inicio = omp_get_wtime();

    // ---------- Region paralela ----------
    // Cada hilo recorre un bloque contiguo de indices y acumula su suma
    // parcial; reduction(+:suma_total) las combina al cerrar la region.
    // El peso de Simpson se deriva del INDICE GLOBAL i, nunca de la
    // posicion dentro del bloque, asi la particion no rompe 1-4-2-4-...-1.
    #pragma omp parallel reduction(+:suma_total)
    {
        int yo = omp_get_thread_num();
        double t0 = omp_get_wtime();
        double suma_local = 0.0;

        #pragma omp for schedule(static) nowait
        for (long long i = 0; i <= n; ++i) {
            double w;
            if (i == 0 || i == n) w = 1.0;      // extremos
            else if (i & 1)       w = 4.0;      // impares
            else                  w = 2.0;      // pares interiores
            suma_local += w * f(a + (double)i * h);
        }

        suma_total += suma_local;
        t_hilo[yo] = omp_get_wtime() - t0;
    }

    double t_total = omp_get_wtime() - t_inicio;

    double tc_max = t_hilo[0], tc_min = t_hilo[0];
    for (int k = 1; k < hilos; ++k) {
        if (t_hilo[k] > tc_max) tc_max = t_hilo[k];
        if (t_hilo[k] < tc_min) tc_min = t_hilo[k];
    }

    double area   = suma_total * h / 3.0;
    double exacta = F(b) - F(a);
    double err    = std::fabs(area - exacta) / std::fabs(exacta);

    std::cout << "==============================================\n"
              << " Area bajo la curva con OpenMP (Simpson 1/3)\n"
              << " f(x) = x(2 + sen x) + 100 e^(-x/100)\n"
              << "==============================================\n";
    std::cout << std::fixed << std::setprecision(2)
              << " Intervalo            : [" << a << ", " << b << "]\n";
    std::cout << " Subintervalos (n)    : " << n << "\n"
              << " Hilos OpenMP         : " << hilos << "\n"
              << " Nucleos disponibles  : " << omp_get_num_procs() << "\n";
    std::cout << std::setprecision(8)
              << " Area calculada       : " << area   << "\n"
              << " Area exacta          : " << exacta << "\n";
    std::cout << std::scientific << std::setprecision(3)
              << " Error relativo       : " << err << "\n";
    std::cout << std::fixed << std::setprecision(4)
              << " Tiempo total (s)     : " << t_total << "\n"
              << " Hilo mas lento (s)   : " << tc_max  << "\n"
              << " Hilo mas rapido (s)  : " << tc_min  << "\n"
              << "==============================================\n";

    // hilos,nucleos,n,area,error_rel,t_total,t_hilo_max,t_hilo_min
    std::cout << "CSV," << hilos << "," << omp_get_num_procs() << "," << n << ","
              << std::setprecision(8) << area << ","
              << std::scientific << std::setprecision(3) << err << ","
              << std::fixed << std::setprecision(6)
              << t_total << "," << tc_max << "," << tc_min << std::endl;

    return 0;
}