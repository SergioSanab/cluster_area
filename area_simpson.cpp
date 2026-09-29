// =====================================================================
//  area_simpson.cpp  -  Area bajo la curva en paralelo con MPI
//  Regla de Simpson 1/3 compuesta
//
//      f(x) = x * (2 + sen(x)) + 100 * e^(-x/100)       en [a, b]
//
//  La funcion es no lineal (oscilante + crecimiento + decaimiento
//  exponencial), siempre positiva en [0, b], y tiene primitiva conocida,
//  asi que el programa tambien reporta el error contra el valor exacto:
//
//      F(x) = x^2 + sen(x) - x*cos(x) - 10000 * e^(-x/100)
//
//  Por defecto integra en [0, 1000]  ->  area aprox. 1.01 millones u^2
//
//  Uso:
//      mpirun -np P --hostfile hosts ./area_simpson [n] [a] [b]
//      n = numero de subintervalos (si es impar se sube al par siguiente)
//
//  Salida: bloque legible + una ultima linea "CSV,..." que leen los scripts.
// =====================================================================

#include <iostream>
#include <iomanip>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <set>
#include <string>
#include <mpi.h>

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
    MPI_Init(&argc, &argv);

    int minodo, totalnodos;
    MPI_Comm_size(MPI_COMM_WORLD, &totalnodos);
    MPI_Comm_rank(MPI_COMM_WORLD, &minodo);

    // ---------- Parametros (los lee el maestro y los reparte) ----------
    long long n = 3000000000LL;          // 3 mil millones de subintervalos
    double ab[2] = {0.0, 1000.0};

    if (minodo == 0) {
        if (argc > 1) n = std::atoll(argv[1]);
        if (argc > 2) ab[0] = std::atof(argv[2]);
        if (argc > 3) ab[1] = std::atof(argv[3]);
        if (n < 2) n = 2;
        if (n % 2 != 0) n++;
    }
    MPI_Bcast(&n, 1, MPI_LONG_LONG, 0, MPI_COMM_WORLD);
    MPI_Bcast(ab, 2, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    // ---------- Quien es quien ----------
    char nombre[MPI_MAX_PROCESSOR_NAME];
    std::memset(nombre, 0, sizeof(nombre));
    int largo;
    MPI_Get_processor_name(nombre, &largo);

    char *nombres = NULL;
    if (minodo == 0) nombres = new char[totalnodos * MPI_MAX_PROCESSOR_NAME];
    MPI_Gather(nombre, MPI_MAX_PROCESSOR_NAME, MPI_CHAR,
            nombres, MPI_MAX_PROCESSOR_NAME, MPI_CHAR, 0, MPI_COMM_WORLD);

    // ---------- Inicio de la medicion ----------
    MPI_Barrier(MPI_COMM_WORLD);
    double t_inicio = MPI_Wtime();

    const double a = ab[0];
    const double b = ab[1];
    const double h = (b - a) / (double)n;

    // Se reparten los n+1 puntos (indices 0..n) en bloques contiguos
    long long puntos = n + 1;
    long long base   = puntos / totalnodos;
    long long resto  = puntos % totalnodos;
    long long ini = minodo * base + (minodo < resto ? minodo : resto);
    long long fin = ini + base + (minodo < resto ? 1 : 0);      // [ini, fin)

    double tc0 = MPI_Wtime();
    double suma_local = 0.0;
    for (long long i = ini; i < fin; ++i) {
        double w;
        if (i == 0 || i == n) w = 1.0;       // extremos
        else if (i & 1)       w = 4.0;       // impares
        else                  w = 2.0;       // pares interiores
        suma_local += w * f(a + (double)i * h);
    }
    double t_calculo = MPI_Wtime() - tc0;

    // ---------- Recoleccion ----------
    double suma_total = 0.0, tc_max = 0.0, tc_min = 0.0;
    MPI_Reduce(&suma_local, &suma_total, 1, MPI_DOUBLE, MPI_SUM, 0, MPI_COMM_WORLD);
    MPI_Reduce(&t_calculo,  &tc_max,     1, MPI_DOUBLE, MPI_MAX, 0, MPI_COMM_WORLD);
    MPI_Reduce(&t_calculo,  &tc_min,     1, MPI_DOUBLE, MPI_MIN, 0, MPI_COMM_WORLD);

    double t_total = MPI_Wtime() - t_inicio;

    // ---------- Reporte (solo el maestro) ----------
    if (minodo == 0) {
        double area   = suma_total * h / 3.0;
        double exacta = F(b) - F(a);
        double err    = std::fabs(area - exacta) / std::fabs(exacta);

        std::set<std::string> distintos;
        for (int r = 0; r < totalnodos; ++r)
            distintos.insert(std::string(&nombres[r * MPI_MAX_PROCESSOR_NAME]));

        std::cout << "==============================================\n"
        << " Area bajo la curva con MPI (Simpson 1/3)\n"
        << " f(x) = x(2 + sen x) + 100 e^(-x/100)\n"
        << "==============================================\n";
        std::cout << std::fixed << std::setprecision(2)
                << " Intervalo            : [" << a << ", " << b << "]\n";
        std::cout << " Subintervalos (n)    : " << n << "\n"
                << " Procesos MPI         : " << totalnodos << "\n"
                << " Nodos distintos      : " << distintos.size() << "\n";
        for (int r = 0; r < totalnodos; ++r)
            std::cout << "    proceso " << r << " -> "
                      << &nombres[r * MPI_MAX_PROCESSOR_NAME] << "\n";

        std::cout << std::setprecision(8)
                << " Area calculada       : " << area   << "\n"
                << " Area exacta          : " << exacta << "\n";
        std::cout << std::scientific << std::setprecision(3)
                << " Error relativo       : " << err << "\n";
        std::cout << std::fixed << std::setprecision(4)
                << " Tiempo total (s)     : " << t_total << "\n"
                << " Calculo mas lento (s): " << tc_max  << "\n"
                << " Calculo mas rapido(s): " << tc_min  << "\n"
                << "==============================================\n";

        // procesos,nodos_distintos,n,area,error_rel,t_total,t_calc_max,t_calc_min
        std::cout << "CSV," << totalnodos << "," << distintos.size() << "," << n << ","
                << std::setprecision(8) << area << ","
                << std::scientific << std::setprecision(3) << err << ","
                << std::fixed << std::setprecision(6)
                << t_total << "," << tc_max << "," << tc_min << std::endl;

        delete[] nombres;
    }

    MPI_Finalize();
    return 0;
}
